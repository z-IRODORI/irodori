//
//  CalendarOwnedFirstSuggestionView.swift
//  irodori
//
//  カレンダーの空いた日 (今日〜6日後) をタップしたときの提案。
//  ホームと同じ「手持ち＋買い足す」の3案を、その日の天気で組む (旧: 他人のコーデ写真の候補)。
//  決めるとホームの「着る」と同じ記録になり、カレンダーには自分の服の1枚画像が残る。
//

import SwiftUI

struct CalendarOwnedFirstSuggestionView: View {
    let data: CalendarDaySuggestionData
    /// 決めたあと (カレンダーを読み直す)
    let onDecided: () async -> Void

    @State private var response: OwnedFirstHomeResponse?
    @State private var failed = false
    @State private var isSending = false
    @State private var detailRecipe: OwnedFirstRecipe?
    @Environment(\.dismiss) private var dismiss

    private let client: OwnedFirstHomeClientProtocol = OwnedFirstHomeClient()

    private var uid: String { UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? "" }
    private var gender: String {
        Gender.fromWithDefault(UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)).apiValue
    }

    /// 今日〜6日後なら、この画面で提案できる (サーバの対象範囲)
    static func supports(date: String, now: Date = Date()) -> Bool {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: date) else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let today = cal.startOfDay(for: now)
        let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: d)).day ?? -1
        return (0...6).contains(days)
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
                } else if failed {
                    VStack(spacing: 12) {
                        Text("提案を取得できませんでした")
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
        .navigationTitle("コーデ候補")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") { dismiss() }.disabled(isSending)
            }
        }
        .sheet(item: $detailRecipe) { recipe in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        RenewalFlatLayBoard(
                            pieces: RenewalFlatLayBuilder.boardPieces(recipe, extraction: recipe.example?.extraction, mode: .exampleItems),
                            showsExampleTag: false, height: 380)
                        Text(recipe.reason).font(.system(size: 14)).lineSpacing(3)
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
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            RenewalPartnerAvatar(typeName: response?.partner_type_name ?? "", size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(data.dateLabel)に着るなら")
                    .font(.system(size: 17, weight: .bold))
                Group {
                    if let w = response?.weather {
                        Text("\(w.max_temp)° / \(w.min_temp)° ・ 手持ちの服から3案")
                    } else {
                        Text("相棒が天気と手持ちの服から組みます")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func actions(_ response: OwnedFirstHomeResponse) -> RenewalRecipeActions {
        RenewalRecipeActions(
            scope: .tomorrow,
            decidedId: response.decided_recipe_id,
            isSending: isSending,
            showCharCount: false,
            visualMode: .exampleItems,
            extraction: { $0.example?.extraction },
            onDetail: { detailRecipe = $0 },
            onDecide: { recipe in Task { await decide(recipe, response: response) } },
            onPivot: {},
            actionLabelOverride: data.replacing ? "この日に変更する" : "この日に着る"
        )
    }

    private func load() async {
        failed = false
        do {
            if case .success(let res) = try await client.get(uid: uid, gender: gender, targetDate: data.date, pivotItemId: nil) {
                response = res
                if res.text_pending == true { await followUpTexts(after: res) }
                return
            }
        } catch {}
        failed = true
    }

    /// 文言が後から入るとき: 少し待って1回だけ取り直し、同じ3案なら差し替える (サーバは保存済みを返すだけ)
    private func followUpTexts(after first: OwnedFirstHomeResponse) async {
        for wait in [4.0, 6.0] {
            try? await Task.sleep(for: .seconds(wait))
            guard let result = try? await client.get(uid: uid, gender: gender, targetDate: data.date, pivotItemId: nil),
                  case .success(let fresh) = result,
                  fresh.recipes.map(\.recipe_id) == first.recipes.map(\.recipe_id) else { return }
            if fresh.text_pending == true { continue }
            withAnimation(.easeInOut(duration: 0.3)) { response = fresh }
            return
        }
    }

    private func decide(_ recipe: OwnedFirstRecipe, response: OwnedFirstHomeResponse) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        let pieces = RenewalFlatLayBuilder.boardPieces(recipe, extraction: recipe.example?.extraction, mode: .exampleItems)
            .map { OwnedFirstBoardPiece(slot: $0.slot, image_url: $0.imageURL, label: $0.label,
                                        owned: $0.kind == .owned || $0.ownedMatch) }
        do {
            if case .success = try await client.wear(uid: uid, recipe: recipe, targetDate: data.date,
                                                     maxTemp: response.weather.max_temp, pieces: pieces) {
                Haptic.notify(.success)
                ToastManager.shared.show("\(data.dateLabel)のコーデに決めました")
                await onDecided()
                dismiss()
                return
            }
        } catch {}
        ToastManager.shared.show("保存に失敗しました。もう一度お試しください")
    }
}
