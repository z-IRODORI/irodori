//
//  HomeDesignD.swift
//  irodori
//
//  案D: 「2A ホーム/明日の提案」(Claude Design 明日の相棒ファーストビュー) の再現サンドボックス。
//  Modernist の作法 = 角丸ゼロ・2px罫線・スクエアサムネ。写真はカラーのまま表示する。
//  データは既存ホームAPI(日次レコメンド)を流用。確認は Xcode Preview で行う。
//

import SwiftUI
import Kingfisher

// MARK: - デザイントークン (Modernist)

private enum DTokens {
    static let accent = Color(red: 232 / 255, green: 56 / 255, blue: 13 / 255)  // これにする / BEST MATCH / 通知ドットのみ
    static let ink = Color.black
    static let paper = Color.white
    static let neutral200 = Color(white: 0.92)
    static let neutral300 = Color(white: 0.84)
    static let neutral500 = Color(white: 0.60)
    static let sub = Color(white: 0.40)
    static let rule: CGFloat = 2
    static let brandTracking: CGFloat = 2.7   // 0.14em × 19pt
}

// MARK: - 小部品

private struct RuleLine: View {
    var color: Color = DTokens.ink

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: DTokens.rule)
    }
}

/// デザインの斜めストライプ。画像プレースホルダ兼ローディングスケルトン。
private struct StripePlaceholder: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 10
            var x = -size.height
            var i = 0
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(
                    path,
                    with: .color(i % 2 == 0 ? DTokens.neutral300 : DTokens.neutral200),
                    lineWidth: step * 0.7
                )
                x += step
                i += 1
            }
        }
        .background(DTokens.neutral200)
        .clipped()
    }
}

private struct SquareThumb: View {
    let url: String
    var size: CGFloat = 44

    var body: some View {
        KFImage(URL(string: url))
            .resizable()
            .placeholder { StripePlaceholder() }
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
            .border(DTokens.neutral300, width: 1)
    }
}

private struct OverflowSquare: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DTokens.sub)
            .frame(width: 44, height: 44)
            .background(DTokens.neutral200)
    }
}

private struct ModernistChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(DTokens.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .border(DTokens.neutral300, width: 1)
    }
}

// MARK: - 本体

struct HomeDesignD: View {
    @State private var viewModel: HomeViewModel
    @State private var currentCardID: String? = nil
    @State private var showPlanListSheet = false
    @State private var showReasonSheet = false
    @State private var isMarkingWorn = false
    private let toastManager = ToastManager.shared

    @MainActor
    init(viewModel: HomeViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? HomeViewModel(apiClient: MockHomeClient()))
    }

    private var daily: DailyRecommendationResponse? { viewModel.dailyRecommendation }
    private var cards: [DailyRecommendationItem] { Array((daily?.recommendations ?? []).prefix(3)) }
    private var currentIndex: Int { cards.firstIndex { $0.id == currentCardID } ?? 0 }
    private var currentCard: DailyRecommendationItem? {
        guard !cards.isEmpty else { return nil }
        return cards[min(currentIndex, cards.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            RuleLine()
            weatherBar
            RuleLine()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    partnerCommentRow
                    contentArea
                    twoSplitBlock
                    Spacer().frame(height: 24)
                }
            }

            bottomCTABar
        }
        .foregroundStyle(DTokens.ink)
        .background(DTokens.paper)
        .task { await viewModel.onAppear() }
        .sheet(isPresented: $showReasonSheet) { reasonSheet }
        .sheet(isPresented: $showPlanListSheet) { planListSheet }
        .overlay(alignment: .top) {
            // ToastView は通常 MainTabView 側に付くため、単体表示のサンドボックスでは自前で重ねる
            if let message = toastManager.message {
                ToastView(message: message, style: toastManager.style)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: toastManager.message)
    }

    // MARK: - ヘッダー

    private var headerBar: some View {
        HStack {
            Text("IRODORI")
                .font(.system(size: 19, weight: .heavy))
                .tracking(DTokens.brandTracking)
            Spacer()
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                    Circle()
                        .fill(DTokens.accent)
                        .frame(width: 6, height: 6)
                        .offset(x: 1, y: -1)
                }
            }
            .font(.system(size: 18, weight: .medium))
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    // MARK: - 天気バー

    private var tomorrowLabel: String {
        guard let daily else { return "TOMORROW --" }
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        inFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inFmt.date(from: daily.target_date) else {
            return "TOMORROW \(daily.target_date)"
        }
        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "en_US_POSIX")
        outFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        outFmt.dateFormat = "M/d EEE"
        return "TOMORROW " + outFmt.string(from: date).uppercased()
    }

    private var weatherBar: some View {
        HStack(spacing: 12) {
            Image(systemName: daily.map { DailyWeatherDisplay.style(for: $0.weather.condition).iconName } ?? "sun.max")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 13))
                .foregroundStyle(DTokens.sub)
            Text(tomorrowLabel)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
            if let weather = daily?.weather {
                HStack(spacing: 0) {
                    Text("\(weather.max_temp)°")
                        .foregroundStyle(DTokens.ink)
                    Text("/\(weather.min_temp)°")
                        .foregroundStyle(DTokens.sub)
                }
                .font(.system(size: 13, weight: .bold))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(DTokens.neutral200)
    }

    // MARK: - 相棒コメント

    private var partnerCommentRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Rectangle().fill(DTokens.ink)
                Rectangle().fill(DTokens.paper).frame(width: 10, height: 10)
            }
            .frame(width: 34, height: 34)
            Text(daily?.partner_comment ?? "明日のコーデ、3案そろえたよ。")
                .font(.system(size: 13))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - コンテンツ (カルーセル / 状態)

    @ViewBuilder
    private var contentArea: some View {
        if !cards.isEmpty {
            cardCarousel
            paginationRow
        } else if viewModel.isLoadingDailyRecommendation {
            loadingCarousel
        } else if viewModel.hasDailyRecommendationError {
            errorBlock
        } else {
            emptyBlock
        }
    }

    private var cardCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(cards) { card in
                    planCard(card, isBest: card.id == cards.first?.id)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $currentCardID)
    }

    private func planCard(_ card: DailyRecommendationItem, isBest: Bool) -> some View {
        VStack(spacing: 0) {
            KFImage(URL(string: card.image_url))
                .resizable()
                .placeholder { StripePlaceholder() }
                .scaledToFill()
                .frame(width: 272, height: 366)
                .clipped()
                .overlay(alignment: .topLeading) {
                    if isBest {
                        Text("BEST MATCH")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(DTokens.paper)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(DTokens.accent)
                    }
                }

            RuleLine()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(styleName(card))
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                    if itemsCount(for: card) > 0 {
                        Text("\(itemsCount(for: card)) ITEMS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DTokens.sub)
                    }
                }
                thumbnailRow(card)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 272)
        .background(DTokens.paper)
        .border(DTokens.ink, width: DTokens.rule)
    }

    @ViewBuilder
    private func thumbnailRow(_ card: DailyRecommendationItem) -> some View {
        let owned = Array(card.owned_items.prefix(4))
        let total = itemsCount(for: card)
        let overflow = max(0, total - owned.count)
        if owned.isEmpty {
            if total > 0 {
                HStack { OverflowSquare(count: total) }
            }
        } else {
            HStack(spacing: 5) {
                ForEach(owned, id: \.item_id) { item in
                    SquareThumb(url: item.image_url)
                }
                if overflow > 0 {
                    OverflowSquare(count: overflow)
                }
            }
        }
    }

    private var paginationRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(cards.indices, id: \.self) { i in
                    Rectangle()
                        .fill(i == currentIndex ? DTokens.ink : DTokens.neutral300)
                        .frame(width: 18, height: 3)
                }
            }
            .animation(.easeOut(duration: 0.15), value: currentIndex)
            Text("\(currentIndex + 1) / \(cards.count) PLANS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(DTokens.sub)
            Spacer()
            Button {
                Haptic.selection()
                showPlanListSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 12, weight: .semibold))
                    Text("一覧で見る")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(DTokens.ink)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - 状態表示 (ローディング / エラー / 空)

    private var loadingCarousel: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 0) {
                    StripePlaceholder()
                        .frame(width: 272, height: 366)
                    RuleLine(color: DTokens.neutral300)
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle()
                            .fill(DTokens.neutral200)
                            .frame(width: 120, height: 14)
                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { _ in
                                Rectangle()
                                    .fill(DTokens.neutral200)
                                    .frame(width: 44, height: 44)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(width: 272)
                .border(DTokens.neutral300, width: DTokens.rule)
            }
        }
        .padding(.leading, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var errorBlock: some View {
        VStack(spacing: 14) {
            Text("提案を読み込めませんでした")
                .font(.system(size: 13))
                .foregroundStyle(DTokens.sub)
            Button {
                Task { await viewModel.refreshDailyRecommendation() }
            } label: {
                Text("再試行")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DTokens.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .border(DTokens.ink, width: DTokens.rule)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var emptyBlock: some View {
        Text("明日の提案はまだありません")
            .font(.system(size: 13))
            .foregroundStyle(DTokens.sub)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
    }

    // MARK: - 2分割ブロック

    private var twoSplitBlock: some View {
        VStack(spacing: 0) {
            RuleLine()
            HStack(spacing: 0) {
                splitCell(icon: "archivebox", title: "アイテムから")
                Rectangle()
                    .fill(DTokens.ink)
                    .frame(width: DTokens.rule)
                splitCell(icon: "bubble.left", title: "相棒に相談")
            }
            .fixedSize(horizontal: false, vertical: true)
            RuleLine()
        }
    }

    private func splitCell(icon: String, title: String) -> some View {
        Button {
            Haptic.selection()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DTokens.neutral500)
            }
            .foregroundStyle(DTokens.ink)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 下部CTA

    private var bottomCTABar: some View {
        VStack(spacing: 0) {
            RuleLine()
            HStack(spacing: 8) {
                Button {
                    Haptic.selection()
                    showReasonSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                        Text("理由")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(DTokens.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .border(DTokens.ink, width: DTokens.rule)

                Button {
                    markWornTapped()
                } label: {
                    HStack {
                        Text(isMarkingWorn ? "記録中..." : "これにする")
                            .font(.system(size: 16, weight: .bold))
                        Spacer()
                    }
                    .foregroundStyle(DTokens.paper)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(DTokens.accent)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .opacity(currentCard == nil ? 0.4 : 1)
            .disabled(currentCard == nil || isMarkingWorn)
        }
        .background(DTokens.paper)
    }

    private func markWornTapped() {
        guard let card = currentCard, !isMarkingWorn else { return }
        // closet 種別は pool_id がプールを指さないため着用記録の対象外
        if card.isCloset {
            toastManager.show("このコーデは記録対象外です")
            return
        }
        Haptic.impact(.medium)
        isMarkingWorn = true
        Task { @MainActor in
            let ok = await viewModel.markWorn(item: card)
            isMarkingWorn = false
            if ok {
                Haptic.notify(.success)
                toastManager.show("明日のコーデに決定しました", style: .normal)
            } else {
                Haptic.notify(.error)
                toastManager.show("記録に失敗しました。時間をおいて再度お試しください")
            }
        }
    }

    // MARK: - 理由シート

    private var reasonSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("このコーデの理由")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.5)
                Spacer()
                Button {
                    showReasonSheet = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DTokens.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            RuleLine()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if let card = currentCard {
                        Text(styleName(card))
                            .font(.system(size: 20, weight: .bold))
                        if let reason = card.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.system(size: 14))
                                .lineSpacing(6)
                        } else if !card.vibe.isEmpty {
                            Text(card.vibe)
                                .font(.system(size: 14))
                                .lineSpacing(6)
                        }
                        if !card.owned_items.isEmpty {
                            sectionLabel("手持ちアイテム")
                            VStack(spacing: 10) {
                                ForEach(card.owned_items, id: \.item_id) { owned in
                                    HStack(spacing: 10) {
                                        SquareThumb(url: owned.image_url)
                                        Text(owned.label)
                                            .font(.system(size: 13))
                                        Spacer()
                                    }
                                }
                            }
                        }
                        if !card.missing_items.isEmpty {
                            sectionLabel("足りないアイテム")
                            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                ForEach(card.missing_items, id: \.self) { missing in
                                    ModernistChip(text: missing)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .foregroundStyle(DTokens.ink)
        .background(DTokens.paper)
        .presentationDetents([.medium, .large])
    }

    // MARK: - 一覧シート

    private var planListSheet: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("ALL PLANS")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.2)
                Text("\(daily?.recommendations.count ?? 0)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DTokens.sub)
                Spacer()
                Button {
                    showPlanListSheet = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DTokens.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            RuleLine()
            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                    spacing: 2
                ) {
                    ForEach(daily?.recommendations ?? []) { item in
                        Button {
                            selectFromList(item)
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    KFImage(URL(string: item.image_url))
                                        .resizable()
                                        .placeholder { StripePlaceholder() }
                                        .scaledToFill()
                                }
                                .clipped()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
        }
        .foregroundStyle(DTokens.ink)
        .background(DTokens.paper)
    }

    private func selectFromList(_ item: DailyRecommendationItem) {
        Haptic.selection()
        showPlanListSheet = false
        // 先頭3件(カルーセル対象)ならスナップ。4件目以降は閲覧のみ
        if cards.contains(where: { $0.id == item.id }) {
            withAnimation { currentCardID = item.id }
        }
    }

    // MARK: - ヘルパー

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(DTokens.sub)
    }

    private func styleName(_ card: DailyRecommendationItem) -> String {
        if !card.style.isEmpty { return card.style }
        if !card.vibe.isEmpty { return card.vibe }
        return "おすすめコーデ"
    }

    private func itemsCount(for card: DailyRecommendationItem) -> Int {
        let named = card.items.compactMapValues { $0 }.count
        if named > 0 { return named }
        return card.owned_items.count + card.missing_items.count
    }
}

#Preview("案D - 明日の提案ファーストビュー(2A)") {
    HomeDesignD(viewModel: HomeViewModel(
        apiClient: MockHomeClient(),
        dailyRecommendationClient: MockDailyRecommendationClient()
    ))
    .environment(MainTabViewModel())
}
