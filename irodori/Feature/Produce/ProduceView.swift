//
//  ProduceView.swift
//  irodori
//
//  相棒のプロデュース (設計書: proposals/2026-11-03-produce.html)。
//  1 枚の縦スクロールに ① キャラクター → ② 合うブランド → ③ 今のおすすめアイテム を並べる。
//  ② のブランドを押すと ③ が選び直され、③ のアイテムを押すと理由の画面が開く。
//  理由の画面の「このアイテムで3案組む」で ④ (ProduceCoordinatesView) へ進む。
//  プロデュースの 4 問にまだ答えていない人には、先に 4 問だけを聞く。
//  見た目は相棒画面と同じ (RenewalTokens・白いカード・黒のカプセルのボタン)。
//

import SwiftUI
import Kingfisher

@MainActor
@Observable
final class ProduceViewModel {
    enum Phase { case loading, answering, ready, failed }

    var phase: Phase = .loading
    var response: ProduceResponse?
    var isReloadingItems = false
    private let client = ProduceClient()

    var uid: String { UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? "" }
    private var gender: String {
        Gender.fromWithDefault(UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)).apiValue
    }

    func load(brandId: String? = nil) async {
        guard !uid.isEmpty else { phase = .failed; return }
        if response == nil { phase = .loading } else { isReloadingItems = true }
        defer { isReloadingItems = false }
        switch await client.fetch(userId: uid, gender: gender, age: BrandMatchView.userAge(), brandId: brandId) {
        case .success(let res):
            response = res
            phase = res.status == "needs_answers" ? .answering : (res.status == "success" ? .ready : .failed)
        case .failure:
            if response == nil { phase = .failed }
        }
    }

    func selectBrand(_ id: String) async {
        guard response?.selected_brand_id != id else { return }
        Haptic.selection()
        await load(brandId: id)
    }

    /// アイテムへの反応。「違う」「もう持ってる」はアイテムを選び直す。
    /// 「もう持ってる」はクローゼットに登録する (決定 C。④ の「持ってる・買った」と同じ)
    func react(_ item: ProduceItem, reaction: String, reason: String? = nil) async {
        if reaction == "owned" {
            if let res = await client.registerOwned(userId: uid, itemKey: item.item_key) {
                NotificationCenter.default.post(name: .closetDidChange, object: res.item_id)
                ToastManager.shared.show(res.registered ? "クローゼットに登録したよ" : "もうクローゼットにあったよ", style: .normal)
            } else {
                ToastManager.shared.show("登録できませんでした。もう一度お試しください")
                return
            }
            await load(brandId: response?.selected_brand_id)
            return
        }
        await client.sendFeedback(userId: uid, itemKey: item.item_key, reaction: reaction, reason: reason)
        if reaction == "like" {
            if var res = response, let i = res.items?.firstIndex(where: { $0.id == item.id }) {
                res.items?[i].reaction = "like"
                response = res
            }
        } else {
            await load(brandId: response?.selected_brand_id)
        }
    }

    /// 「ファッション感度を見る」を押した
    func revealSense() async {
        if case .success = try? await PartnerClient().setFashionSenseVisible(userId: uid) {
            await load(brandId: response?.selected_brand_id)
        }
    }
}

struct ProduceView: View {
    @Binding var path: [ViewType]
    @State private var viewModel = ProduceViewModel()
    @State private var openedItem: ProduceItem?

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .answering:
                ProduceQuestionsView {
                    Task { await viewModel.load() }
                }
            case .failed:
                failedView
            case .ready:
                if let res = viewModel.response { content(res) }
            }
        }
        .background(RenewalTokens.ground.ignoresSafeArea())
        .navigationTitle("プロデュース")
        .navigationBarTitleDisplayMode(.inline)
        .task { if viewModel.response == nil { await viewModel.load() } }
        // ④ で「持ってる・買った」を押したら、そのアイテムを除いて選び直す
        .onReceive(NotificationCenter.default.publisher(for: .closetDidChange)) { _ in
            guard viewModel.phase == .ready else { return }
            Task { await viewModel.load(brandId: viewModel.response?.selected_brand_id) }
        }
        .sheet(item: $openedItem) { item in
            ProduceItemSheet(item: item, brand: viewModel.response?.brands?.first { $0.id == item.brand_id },
                             onReact: { reaction, reason in
                                 openedItem = nil
                                 Task { await viewModel.react(item, reaction: reaction, reason: reason) }
                             },
                             onCompose: {
                                 openedItem = nil
                                 path.append(.produceCoordinates(item))
                             })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func content(_ res: ProduceResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                characterCard(res)
                brandsCard(res)
                itemsSection(res)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: ① キャラクター

    private func characterCard(_ res: ProduceResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            stepLabel("① あなたのキャラクター")
            HStack(spacing: 12) {
                PartnerIconImage(size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(res.character.type_name ?? "あなた")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(RenewalTokens.ink)
                    if let sub = res.character.subtitle {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
            }
            HStack(spacing: 6) {
                if let budget = res.budget_tier {
                    chip("予算感 1着 \(Self.budgetLabel(budget))")
                }
                senseChip(res.fashion_sense)
            }
            if let line = Self.partnerLine(res.fashion_sense) {
                Text(line)
                    .font(.system(size: 13))
                    .foregroundStyle(RenewalTokens.ink)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .partnerSoftCard()
    }

    /// 点数はふだん隠す。「見る」を押した人にだけ出す
    @ViewBuilder
    private func senseChip(_ sense: FashionSense?) -> some View {
        if let sense, sense.answered {
            if sense.visible, let score = sense.score {
                chip("ファッション感度 \(score) / 100")
            } else {
                Button {
                    Haptic.selection()
                    Task { await viewModel.revealSense() }
                } label: {
                    HStack(spacing: 3) {
                        Text("ファッション感度：ひみつ")
                        Text("見る").underline()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(RenewalTokens.raised, in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("ファッション感度を見る")
            }
        }
    }

    static func partnerLine(_ sense: FashionSense?) -> String? {
        switch sense?.level {
        case "beginner": return "はじめての人にも着やすい、定番から選んだよ。"
        case "enthusiast": return "こだわりのあるあなたに、少し攻めた系統も入れたよ。"
        default: return nil
        }
    }

    /// 予算の価格帯 (1〜5) を、トップスの価格の目安に直す
    static func budgetLabel(_ tier: Double) -> String {
        switch Int(tier.rounded()) {
        case ...1: return "〜3千円"
        case 2: return "3千〜1万円"
        case 3: return "1〜2.5万円"
        case 4: return "2.5〜6万円"
        default: return "6万円〜"
        }
    }

    // MARK: ② ブランド

    private func brandsCard(_ res: ProduceResponse) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            stepLabel("② あなたに合うブランド")
            Text("押すと、そのブランドの系統でアイテムを選び直すよ")
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
                .padding(.bottom, 4)
            ForEach(res.brands ?? []) { brand in
                let selected = brand.id == res.selected_brand_id
                Button {
                    Task { await viewModel.selectBrand(brand.id) }
                } label: {
                    HStack(spacing: 12) {
                        logo(brand)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(brand.displayName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(RenewalTokens.ink)
                            if let reason = brand.reasons?.first {
                                Text("✓ \(reason)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(RenewalTokens.muted)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? RenewalTokens.ink : RenewalTokens.controlBorder)
                    }
                    .padding(10)
                    .background(selected ? RenewalTokens.raised : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Button {
                path.append(.brandMatch)
            } label: {
                Text("10 ブランドを見る ›")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(minHeight: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .partnerSoftCard()
    }

    private func logo(_ brand: ProduceBrand) -> some View {
        Group {
            if let url = brand.logoURL {
                KFImage(url).placeholder { RenewalTokens.raised }.resizable().scaledToFit().padding(4)
            } else {
                Text(String(brand.displayName.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RenewalTokens.muted)
            }
        }
        .frame(width: 44, height: 44)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(RenewalTokens.border, lineWidth: 1))
    }

    // MARK: ③ アイテム

    private func itemsSection(_ res: ProduceResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            stepLabel("③ 今のおすすめアイテム")
            if let s = res.season?.first {
                Text("\(s.month)の平年は最高 \(Int(s.max_temp))℃。これからの季節に着られるものから選んだよ")
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(res.items ?? []) { item in
                        Button { openedItem = item } label: { itemCard(item) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .opacity(viewModel.isReloadingItems ? 0.4 : 1)
            .overlay { if viewModel.isReloadingItems { ProgressView() } }
            if (res.items ?? []).isEmpty {
                Text("今の季節に合うアイテムが見つからなかったよ")
                    .font(.system(size: 13))
                    .foregroundStyle(RenewalTokens.muted)
            }
        }
    }

    private func itemCard(_ item: ProduceItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            itemImage(item, height: 150)
            Text(item.label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
            HStack(spacing: 4) {
                ForEach(item.reasons.prefix(3), id: \.kind) { r in chip(r.label) }
            }
            if item.reaction == "like" {
                Label("いいね済み", systemImage: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenewalTokens.accentPink)
            }
        }
        .padding(10)
        .frame(width: 170)
        .partnerSoftCard(16)
    }

    // MARK: 部品

    private func stepLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(RenewalTokens.accentPink)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(RenewalTokens.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RenewalTokens.raised, in: Capsule())
    }

    private var failedView: some View {
        VStack(spacing: 12) {
            Text("プロデュースを読み込めませんでした")
                .font(.system(size: 15, weight: .semibold))
            Button("もう一度") { Task { await viewModel.load() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// アイテムの画像 (アイテムカタログの商品風の画像)
@MainActor
func itemImage(_ item: ProduceItem, height: CGFloat) -> some View {
    ZStack {
        RenewalTokens.raised
        if let s = item.image_url, let url = URL(string: s) {
            KFImage(url).placeholder { RenewalShimmer() }.resizable().scaledToFit().padding(8)
        }
    }
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

// MARK: - アイテムの理由の画面

struct ProduceItemSheet: View {
    let item: ProduceItem
    let brand: ProduceBrand?
    /// (reaction, reason) like | dislike + taste/season/price | owned
    let onReact: (String, String?) -> Void
    /// 「このアイテムで3案組む」(④ へ)
    let onCompose: () -> Void

    @State private var askingReason = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                itemImage(item, height: 260)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RenewalTokens.ink)
                    if let brand {
                        Text("「\(brand.displayName)」が扱っていそうな系統のアイテム")
                            .font(.system(size: 12))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("相棒がこれを選んだ理由")
                        .font(.system(size: 13, weight: .bold))
                    ForEach(item.reasons, id: \.kind) { r in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(r.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(RenewalTokens.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RenewalTokens.raised, in: Capsule())
                            Text(r.text)
                                .font(.system(size: 13))
                                .foregroundStyle(RenewalTokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let hint = item.price_hint {
                        Text(hint)
                            .font(.system(size: 12))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
                .padding(14)
                .partnerSoftCard(16)
                Text("ブランドの実際の商品ではなく、その系統のアイテムの例です。")
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
                reactButton("このアイテムで3案組む", filled: true, action: onCompose)
                HStack(spacing: 10) {
                    reactButton(item.reaction == "like" ? "♥ いいね済み" : "♡ いいね", filled: false) {
                        onReact("like", nil)
                    }
                    reactButton("違う", filled: false) { askingReason = true }
                }
            }
            .padding(20)
        }
        .background(RenewalTokens.ground.ignoresSafeArea())
        .confirmationDialog("どこが違った？", isPresented: $askingReason, titleVisibility: .visible) {
            Button("好みじゃない") { onReact("dislike", "taste") }
            Button("季節に合わない") { onReact("dislike", "season") }
            Button("高そう") { onReact("dislike", "price") }
            Button("もう持ってる") { onReact("owned", nil) }
            Button("やめる", role: .cancel) {}
        }
    }

    private func reactButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(filled ? .white : RenewalTokens.ink)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(filled ? RenewalTokens.primaryFill : RenewalTokens.surface, in: Capsule())
                .overlay(Capsule().stroke(RenewalTokens.controlBorder, lineWidth: filled ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}
