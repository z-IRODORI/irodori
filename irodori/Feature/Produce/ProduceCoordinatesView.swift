//
//  ProduceCoordinatesView.swift
//  irodori
//
//  プロデュース ④: まだ持っていない服 (③ のアイテム) を主役にした今日の 3 案。
//  組み方とカードはホームの 3 案と同じ (RenewalListLayout)。違いは次の 2 つだけ:
//   - ボードは「手持ち＋主役 (カタログの画像)」で並べる (コーデモデルの写真の服には置き換えない)
//   - 「着る」の代わりに「持ってる・買った」。押すと主役をクローゼットに登録し、次からホームの 3 案に使われる
//  いいね / ちょっと違う はホームと同じ記録 (source=produce) に残す。
//

import SwiftUI

struct ProduceCoordinatesView: View {
    let item: ProduceItem

    @State private var response: OwnedFirstHomeResponse?
    @State private var failed = false
    @State private var isSending = false
    @State private var registered: Bool
    @State private var reactions: [String: RenewalRecipeReaction] = [:]
    @State private var detailRecipe: OwnedFirstRecipe?

    private let client = OwnedFirstHomeClient()

    init(item: ProduceItem) {
        self.item = item
        _registered = State(initialValue: item.reaction == "owned")
    }

    private var uid: String { UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? "" }
    private var gender: String {
        Gender.fromWithDefault(UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)).apiValue
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                    .padding(.horizontal, 20)
                if let response {
                    if !response.greeting.isEmpty {
                        Text(response.greeting)
                            .font(.system(size: 13))
                            .foregroundStyle(RenewalTokens.muted)
                            .lineSpacing(3)
                            .padding(.horizontal, 20)
                    }
                    RenewalListLayout(recipes: response.recipes, actions: actions(response))
                    Text("主役はブランドの実際の商品ではなく、その系統のアイテムの例です。")
                        .font(.system(size: 11))
                        .foregroundStyle(RenewalTokens.muted)
                        .padding(.horizontal, 20)
                } else if failed {
                    VStack(spacing: 12) {
                        Text("コーデを組めませんでした")
                            .font(.system(size: 14, weight: .semibold))
                        Button("再読み込み") { Task { await load() } }
                            .buttonStyle(RenewalPrimaryButtonStyle(filled: false))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    RenewalPartnerLoadingView(typeName: "", compact: true)
                        .frame(width: 168, height: 168)
                        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 22))
                        .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(RenewalTokens.ground)
        .navigationTitle("コーデ 3 案")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detailRecipe) { recipe in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        RenewalFlatLayBoard(pieces: RenewalFlatLayBuilder.ownedPlusExample(recipe, extraction: nil), height: 380)
                        Text(recipe.reason).font(.system(size: 14)).lineSpacing(3)
                        if recipe.example?.image_url?.isEmpty == false {
                            Text("近い着こなしのコーデモデル")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(RenewalTokens.muted)
                            RenewalRemoteExampleImage(example: recipe.example, height: 320, showBadge: false)
                        }
                    }
                    .padding(20)
                }
                .navigationTitle(recipe.displayTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { detailRecipe = nil } }
                }
            }
        }
        .task { if response == nil { await load() } }
    }

    private var header: some View {
        HStack(spacing: 12) {
            itemImage(item, height: 64)
                .frame(width: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(item.label)が主役")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(2)
                Group {
                    if let w = response?.weather {
                        Text("今日 \(w.max_temp)° / \(w.min_temp)° ・ 手持ちの服と合わせた 3 案")
                    } else {
                        Text("相棒が今日の天気と手持ちの服から組みます")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                if registered {
                    Label("クローゼットに登録済み", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func actions(_ response: OwnedFirstHomeResponse) -> RenewalRecipeActions {
        RenewalRecipeActions(
            scope: .today,
            decidedId: nil,
            isSending: isSending,
            showCharCount: false,
            visualMode: .ownedPlusExample,
            // コーデモデルの写真の服には置き換えず、主役はプロデュースで見せた画像のまま並べる
            extraction: { _ in nil },
            onDetail: { detailRecipe = $0 },
            onDecide: { _ in Task { await registerOwned() } },
            onPivot: {},
            partnerTypeName: response.partner_type_name,
            reaction: { reactions[$0.recipe_id] },
            onLike: { recipe in Task { await send(recipe, reason: "like", colorTarget: nil) } },
            onDislike: { recipe, reason, target in Task { await send(recipe, reason: reason.rawValue, colorTarget: target) } },
            actionLabelOverride: "持ってる・買った",
            decidedLabel: "登録済み",
            decidedAll: registered
        )
    }

    private func load() async {
        failed = false
        do {
            if case .success(let res) = try await client.produceCoordinates(uid: uid, gender: gender, itemKey: item.item_key) {
                response = res
                if res.text_pending == true { await followUpTexts(after: res) }
                return
            }
        } catch {}
        failed = true
    }

    /// 文言が後から入るとき: 少し待って 1 回だけ取り直し、同じ 3 案なら差し替える (ホーム・カレンダーと同じ)
    private func followUpTexts(after first: OwnedFirstHomeResponse) async {
        for wait in [4.0, 6.0] {
            try? await Task.sleep(for: .seconds(wait))
            guard let result = try? await client.produceCoordinates(uid: uid, gender: gender, itemKey: item.item_key),
                  case .success(let fresh) = result,
                  fresh.recipes.map(\.recipe_id) == first.recipes.map(\.recipe_id) else { return }
            if fresh.text_pending == true { continue }
            withAnimation(.easeInOut(duration: 0.3)) { response = fresh }
            return
        }
    }

    private func send(_ recipe: OwnedFirstRecipe, reason: String, colorTarget: RenewalColorTarget?) async {
        guard let response else { return }
        reactions[recipe.recipe_id] = .sending
        if reason == "like" { Haptic.selection() }
        let result = try? await client.produceFeedback(uid: uid, targetDate: response.target_date, reason: reason,
                                                       recipe: recipe, colorTarget: colorTarget)
        guard case .success(let res) = result else {
            reactions[recipe.recipe_id] = .failed
            return
        }
        if reason == "like" {
            reactions[recipe.recipe_id] = .liked(res.ack_message)
        } else if let r = RenewalDislikeReason(rawValue: reason) {
            reactions[recipe.recipe_id] = .disliked(r, res.ack_message)
        }
    }

    /// 「持ってる・買った」: 主役をクローゼットに登録する (どの案から押しても同じ 1 着)
    private func registerOwned() async {
        guard !isSending, !registered else { return }
        isSending = true
        defer { isSending = false }
        guard let res = await ProduceClient().registerOwned(userId: uid, itemKey: item.item_key) else {
            Haptic.notify(.error)
            ToastManager.shared.show("登録できませんでした。もう一度お試しください")
            return
        }
        Haptic.notify(.success)
        registered = true
        NotificationCenter.default.post(name: .closetDidChange, object: res.item_id)
        ToastManager.shared.show(res.registered
            ? "クローゼットに登録したよ。次からホームの3案にも使うね"
            : "もうクローゼットにあったよ。プロデュースには出さないね", style: .normal)
    }
}
