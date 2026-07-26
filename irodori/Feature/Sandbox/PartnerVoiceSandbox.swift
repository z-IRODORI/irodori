//
//  PartnerVoiceSandbox.swift
//  irodori
//
//  「相棒が自分の行動から考えて提案してくれている」UX候補 (A〜D) の比較サンドボックス。
//  画面上部のトグルで候補を個別にON/OFFし、組み合わせ (推奨: A+B+C) を実データで確認する。
//
//  - A 根拠キャプション: カードに「手持ちの◯◯が活きる」等の相棒声を1行
//  - B 事実引用コメント: 相棒コメントが行動を引用+帰属行+仕組みシート
//  - C 思考ローディング: 待ち時間に「天気を確認中…」等の思考ステップ
//  - D 今日の見立てカード: カルーセル先頭に観察サマリカード
//
//  本番実装との差分: A/B はサーバ側で着用履歴・フィードバック履歴から判定/合成するが、
//  サンドボックスでは response から得られる実データ (owned_items / is_discovery /
//  天気 / テイスト枠の傾向) を使った近似で再現している。C/D は本番と同等。
//

import SwiftUI
import Kingfisher

// MARK: - 候補トグル

private struct VoiceCandidates {
    var evidence = true       // A: 根拠キャプション
    var quoteComment = true   // B: 事実引用コメント
    var thinking = true       // C: 思考ローディング
    var briefCard = false     // D: 今日の見立てカード
}

// MARK: - 小部品

/// 発見枠バッジ (本番 TomorrowPickSection の DiscoveryBadge と同意匠)
private struct SandboxDiscoveryBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .semibold))
            Text("挑戦")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.teal)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.teal.opacity(0.35), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

private struct SandboxShimmer: ViewModifier {
    @State private var phase: CGFloat = -0.55

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 0.55, height: geo.size.height)
                    .offset(x: geo.size.width * phase)
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    fileprivate func sandboxShimmering() -> some View {
        modifier(SandboxShimmer())
    }
}

// MARK: - 本体

struct PartnerVoiceSandbox: View {
    @State private var viewModel: HomeViewModel
    @State private var candidates = VoiceCandidates()
    @State private var currentCardID: String? = nil
    @State private var thinkingIndex = 0
    @State private var showMechanismSheet = false
    private let toastManager = ToastManager.shared
    private let thinkingTimer = Timer.publish(every: 1.4, on: .main, in: .common).autoconnect()

    @MainActor
    init(viewModel: HomeViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? HomeViewModel(apiClient: MockHomeClient()))
    }

    private var daily: DailyRecommendationResponse? { viewModel.dailyRecommendation }
    private var cards: [DailyRecommendationItem] { Array((daily?.recommendations ?? []).prefix(3)) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    scopeSegments
                    infoRow
                    commentArea
                    contentArea
                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
        }
        .background(Color.gray.opacity(0.08))
        .task { await viewModel.onAppear() }
        .onChange(of: viewModel.selectedPickScope) { _, _ in currentCardID = nil }
        .sheet(isPresented: $showMechanismSheet) { mechanismSheet }
        .overlay(alignment: .top) {
            if let message = toastManager.message {
                ToastView(message: message, style: toastManager.style)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: toastManager.message)
    }

    // MARK: - ヘッダー + 候補トグル

    private var header: some View {
        VStack(spacing: 10) {
            Text("相棒ボイス比較")
                .font(.system(size: 16, weight: .semibold))
            HStack(spacing: 8) {
                toggleChip("A 根拠", isOn: $candidates.evidence)
                toggleChip("B 引用", isOn: $candidates.quoteComment)
                toggleChip("C 思考", isOn: $candidates.thinking)
                toggleChip("D 見立て", isOn: $candidates.briefCard)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.white)
    }

    private func toggleChip(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            Haptic.selection()
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isOn.wrappedValue ? .white : .black)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isOn.wrappedValue ? Color.black : Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.gray.opacity(isOn.wrappedValue ? 0 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - タブ + 情報行

    private var scopeSegments: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.pickTabs) { tab in
                let isSelected = tab.scope == viewModel.selectedPickScope
                Button {
                    Haptic.selection()
                    viewModel.selectPickScope(tab.scope)
                } label: {
                    Text(tab.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.black : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.gray.opacity(isSelected ? 0 : 0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var infoRow: some View {
        HStack(spacing: 8) {
            if let tab = viewModel.pickTabs.first(where: { $0.scope == viewModel.selectedPickScope }) {
                Text(tab.shortDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            DailyLocationBadge(prefectureName: viewModel.currentPrefectureName, action: { Haptic.selection() })
            if let weather = daily?.weather {
                DailyMiniWeatherBadge(weather: weather)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - B: 相棒コメント (事実引用) + 帰属行

    private var commentArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                PartnerIconImage(size: 44)
                DailyPartnerCommentBox(text: displayComment)
            }
            if candidates.quoteComment {
                HStack(spacing: 4) {
                    Text("あなたの着用・♡・👎から相棒が毎日選び直しています")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Button {
                        Haptic.selection()
                        showMechanismSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 54)
            }
        }
        .padding(.horizontal, 24)
    }

    private var displayComment: String {
        guard let daily else {
            return "\(viewModel.selectedPickScope.displayName)のコーデを考え中…"
        }
        if candidates.quoteComment {
            return personalComment(daily)
        }
        return daily.partner_comment ?? "\(viewModel.selectedPickScope.displayName)のコーデ、3案そろえたよ。"
    }

    /// B: 事実引用コメント。
    /// 本番はサーバが着用履歴・フィードバック履歴から合成する。サンドボックスでは
    /// response の実データ (テイスト枠の傾向 / 手持ち一致数 / 挑戦枠ジャンル) で近似。
    private func personalComment(_ daily: DailyRecommendationResponse) -> String {
        var parts: [String] = []
        let tasteStyles = daily.recommendations
            .filter { !$0.is_discovery }
            .map(\.style)
            .filter { !$0.isEmpty }
        if let dominant = mostFrequent(tasteStyles) {
            parts.append("最近の君は\(dominant)系が多めだね。\(viewModel.selectedPickScope.displayName)もその流れで選んでみた。")
        }
        let ownedCount = cards.filter { !$0.owned_items.isEmpty }.count
        if ownedCount > 0 {
            parts.append("\(ownedCount)案は手持ちが活きるはず。")
        }
        let discGenres = Array(
            Set(cards.filter(\.is_discovery).map(\.style).filter { !$0.isEmpty })
        ).sorted()
        if !discGenres.isEmpty {
            parts.append("いつもと違う\(discGenres.joined(separator: "・"))系の挑戦も混ぜてあるよ。")
        }
        parts.append("気になったら♡か👎で教えてね！")
        return parts.joined(separator: " ")
    }

    private func mostFrequent(_ values: [String]) -> String? {
        guard !values.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }

    // MARK: - コンテンツ (カルーセル / C: 思考ローディング)

    @ViewBuilder
    private var contentArea: some View {
        if !cards.isEmpty {
            carousel
            paginationRow
        } else if viewModel.isLoadingDailyRecommendation {
            VStack(alignment: .leading, spacing: 12) {
                if candidates.thinking {
                    thinkingHeader
                }
                loadingSkeleton
            }
        } else if viewModel.hasDailyRecommendationError {
            errorRow
        } else {
            emptyRow
        }
    }

    /// C: 相棒の思考ステップ (サーバで実際に起きている処理順)
    private var thinkingSteps: [String] {
        [
            "\(viewModel.currentPrefectureName)の天気を確認中…",
            "最近の着こなしを見返し中…",
            "クローゼットと照合中…",
            "3案に絞り込み中…",
        ]
    }

    private var thinkingHeader: some View {
        HStack(spacing: 10) {
            PartnerIconImage(size: 28)
            Text(thinkingSteps[thinkingIndex % thinkingSteps.count])
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .id(thinkingIndex)
                .transition(.opacity)
            Spacer()
        }
        .padding(.horizontal, 24)
        .onReceive(thinkingTimer) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { thinkingIndex += 1 }
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                if candidates.briefCard {
                    briefCard
                        .id("brief")
                }
                ForEach(cards) { card in
                    planCard(card, isBest: card.id == cards.first?.id)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $currentCardID)
    }

    // MARK: - D: 今日の見立てカード

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            PartnerIconImage(size: 44)
            Text("\(viewModel.selectedPickScope.displayName)の見立て")
                .font(.system(size: 18, weight: .bold))
            VStack(alignment: .leading, spacing: 12) {
                if let dominant = mostFrequent(
                    (daily?.recommendations ?? []).filter { !$0.is_discovery }.map(\.style).filter { !$0.isEmpty }
                ) {
                    briefRow(icon: "clock.arrow.circlepath", text: "最近の傾向: \(dominant)系")
                }
                if let w = daily?.weather {
                    briefRow(icon: "thermometer.sun", text: "\(w.max_temp)°/\(w.min_temp)° \(w.condition)")
                }
                briefRow(
                    icon: "tshirt",
                    text: "手持ち活かし\(cards.filter { !$0.owned_items.isEmpty }.count)案 + 挑戦\(cards.filter(\.is_discovery).count)案"
                )
            }
            Spacer()
            HStack(spacing: 6) {
                Text("スワイプで3案を見る")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 272, height: 480, alignment: .topLeading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func briefRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
        }
    }

    // MARK: - カード (A: 根拠キャプション)

    private func planCard(_ card: DailyRecommendationItem, isBest: Bool) -> some View {
        VStack(spacing: 0) {
            KFImage(URL(string: card.image_url))
                .resizable()
                .placeholder { Color.gray.opacity(0.15) }
                .scaledToFill()
                .frame(width: 272, height: 340)
                .clipped()
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        if isBest {
                            DailyIchioshiBadge()
                        }
                        if card.is_discovery {
                            SandboxDiscoveryBadge()
                        }
                    }
                    .padding(10)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(card.style.isEmpty ? (card.vibe.isEmpty ? "おすすめコーデ" : card.vibe) : card.style)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                if !card.owned_items.isEmpty {
                    OwnedItemCircles(items: card.owned_items, size: 28, maxCount: 4, background: .white)
                }
                if candidates.evidence, let ev = evidence(for: card) {
                    HStack(spacing: 5) {
                        PartnerIconImage(size: 16)
                        Text(ev)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Button {
                    Haptic.impact(.medium)
                    ToastManager.shared.show("比較用サンドボックスのため記録しません", style: .normal)
                } label: {
                    Text("これにする")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 272)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// A: 根拠キャプション。
    /// 本番はサーバが選定に実際に効いた信号から判定する。サンドボックスでは
    /// response から判定できる範囲 (挑戦枠 > 手持ち一致 > お気に入り > 天気) で近似。
    private func evidence(for card: DailyRecommendationItem) -> String? {
        if card.is_discovery {
            let g = card.style.isEmpty ? "新しい" : card.style
            return "いつもと違う\(g)系への挑戦"
        }
        if let owned = card.owned_items.first {
            return "手持ちの\(owned.label)が活きる"
        }
        if card.is_favorite {
            return "お気に入りしたコーデ"
        }
        if let w = daily?.weather {
            return "\(w.max_temp)°の\(w.condition)向き"
        }
        return nil
    }

    // MARK: - ページネーション / 状態

    private var pageIDs: [String] {
        (candidates.briefCard ? ["brief"] : []) + cards.map(\.id)
    }

    private var paginationRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(pageIDs, id: \.self) { pid in
                    Circle()
                        .fill(pid == (currentCardID ?? pageIDs.first) ? Color.black : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var loadingSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 272, height: 340)
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.12))
                                .frame(width: 120, height: 14)
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.12))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .padding(12)
                    }
                    .frame(width: 272)
                    .background(.white)
                    .sandboxShimmering()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
            }
        }
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .scrollDisabled(true)
    }

    private var errorRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 20))
                .foregroundStyle(Color.gray.opacity(0.5))
            Text("提案を読み込めませんでした")
                .font(.system(size: 14, weight: .semibold))
            Button {
                Task { await viewModel.refreshDailyRecommendation() }
            } label: {
                Text("再試行")
                    .font(.system(size: 13))
                    .underline()
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }

    private var emptyRow: some View {
        Text("提案はまだありません")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
    }

    // MARK: - B: 仕組みシート (透明性)

    private var mechanismSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("相棒は、あなたのアプリ内の行動だけを見て提案を選んでいます。")
                        .font(.system(size: 13))
                        .lineSpacing(5)
                    mechanismRow(icon: "tshirt", title: "着用の記録",
                                 desc: "「これにする」で選んだコーデの系統を学習します。")
                    mechanismRow(icon: "heart", title: "♡ と 👎",
                                 desc: "好みは寄せて、興味なしのコーデは以後出しません。")
                    mechanismRow(icon: "archivebox", title: "クローゼット",
                                 desc: "手持ちのアイテムが活きるコーデを優先します。")
                    mechanismRow(icon: "sun.max", title: "天気",
                                 desc: "その日の気温に合うものだけを選びます。")
                    mechanismRow(icon: "sparkles", title: "挑戦枠",
                                 desc: "新しい発見のため、いつもと違う系統も少しだけ混ぜます。")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .navigationTitle("この提案のしくみ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { showMechanismSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func mechanismRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - Preview

/// Preview コンテナは UserDefaults が空のため、未設定時のみ検証用の uid / 性別を入れる
private func configureSandboxAPIUser() {
    let ud = UserDefaults.standard
    if (ud.string(forKey: UserDefaultsKey.userId.rawValue) ?? "").isEmpty {
        ud.set("ios-sandbox-preview", forKey: UserDefaultsKey.userId.rawValue)
    }
    if (ud.string(forKey: UserDefaultsKey.gender.rawValue) ?? "").isEmpty {
        ud.set(Gender.female.rawValue, forKey: UserDefaultsKey.gender.rawValue)
    }
}

/// C (思考演出) 確認用: 4秒待ってからモックを返すクライアント
private final class SlowMockDailyRecommendationClient: DailyRecommendationClientProtocol {
    func get(uid: String, gender: Gender, targetDate: String?) async throws -> Result<DailyRecommendationResponse, HTTPError> {
        try await Task.sleep(nanoseconds: 4_000_000_000)
        return .success(.mock())
    }

    func markWorn(uid: String, poolId: String, wornDate: String) async throws -> Result<WearMarkResponse, HTTPError> {
        .success(.init(status: "ok", pool_id: poolId, worn_date: wornDate))
    }

    func postFeedback(uid: String, poolId: String, rating: String, reasons: [String], targetDate: String?) async throws -> Result<RecommendationFeedbackResponse, HTTPError> {
        .success(.init(status: "ok", pool_id: poolId, rating: rating))
    }
}

#Preview("相棒ボイス比較 (Mock)") {
    PartnerVoiceSandbox(viewModel: HomeViewModel(
        apiClient: MockHomeClient(),
        dailyRecommendationClient: MockDailyRecommendationClient()
    ))
}

#Preview("相棒ボイス比較 (実API・日次のみ実通信)") {
    configureSandboxAPIUser()
    return PartnerVoiceSandbox(viewModel: HomeViewModel(
        apiClient: MockHomeClient(),
        coordinateRecommendClient: MockCoordinateRecommendClient(),
        analyzeRecentCoordinateClient: MockAnalyzeRecentCoordinateClient(),
        closetClient: MockClosetClient(),
        deleteCoordinateClient: MockDeleteCoordinateClient(),
        dailyRecommendationClient: DailyRecommendationClient(),
        closetBridgeClient: MockClosetBridgeClient(),
        outfitCollageClient: MockOutfitCollageClient()
    ))
}

#Preview("C 思考ローディング (4秒遅延)") {
    PartnerVoiceSandbox(viewModel: HomeViewModel(
        apiClient: MockHomeClient(),
        dailyRecommendationClient: SlowMockDailyRecommendationClient()
    ))
}
