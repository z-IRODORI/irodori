//
//  HomeDesignD.swift
//  irodori
//
//  案D: 「2A ホーム/明日の提案」(Claude Design 明日の相棒ファーストビュー) の再現サンドボックス。
//  情報設計(3案カルーセル+下部固定CTA+理由/一覧シート)は 2A のまま、
//  視覚言語は IRODORI の既存デザイン(角丸16白カード・薄影・黒プライマリ・カプセルバッジ・
//  円形アイテムサムネ・日本語ラベル)に寄せている。Modernist 版は git 履歴 (00d7320) を参照。
//  データは既存ホームAPI(日次レコメンド)を流用。確認は Xcode Preview で行う。
//

import SwiftUI
import Kingfisher

// MARK: - 小部品 (IRODORI 視覚言語)

/// 買い足し候補の集約バッジ。既存の NoOwnedItemBadge (破線サークル=未所持) と
/// 同じ視覚言語に「+n」(足りない点数) を載せ、常に1個だけ表示する。
/// タップで理由シートの「買い足すなら」(名前付き一覧) を開く。
private struct BuyItemCircle: View {
    let count: Int
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
            Circle()
                .strokeBorder(
                    Color.gray.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2])
                )
            Text("+\(count)")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Color.gray.opacity(0.8))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 0.5)
        .contentShape(Circle())
    }
}

/// 買い足し行の「探す」ピル (購入導線)
private struct SearchPill: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
            Text("探す")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(Capsule().stroke(Color.gray.opacity(0.35), lineWidth: 1))
        .contentShape(Capsule())
    }
}

/// 構成リストの未所持サムネ (破線サークル=未所持の視覚言語)
private struct MissingItemThumb: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
            Circle()
                .strokeBorder(
                    Color.gray.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2])
                )
            Image(systemName: "plus")
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(Color.gray.opacity(0.7))
        }
        .frame(width: size, height: size)
    }
}

/// 達成度セグメントバー。構成アイテム数ぶんの区画を手持ち数だけ塗り、
/// 「あと少しで完成」の感覚を一目で伝える。
private struct CompletionSegments: View {
    let owned: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < owned ? Color.black : Color.gray.opacity(0.22))
                    .frame(height: 4)
            }
        }
    }
}

/// 理由シートの手持ちアイテム行で使う円形サムネ
private struct CircleThumb: View {
    let url: String
    var size: CGFloat = 44

    var body: some View {
        KFImage(URL(string: url))
            .resizable()
            .placeholder { Color.gray.opacity(0.15) }
            .scaledToFill()
            .frame(width: size, height: size)
            .background(.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - シマー (メルカリ風スケルトン)
// グレーのプレースホルダの上を、斜めの光の帯が左→右へ流れ続ける。
// 参考: https://engineering.mercari.com/blog/entry/2020-07-14-101026/

private struct ShimmerModifier: ViewModifier {
    /// 光帯の位置。-bandRatio(完全に左外) → 1.0(完全に右外) を繰り返す
    @State private var phase: CGFloat = ShimmerModifier.startPhase
    private static let bandRatio: CGFloat = 0.55
    private static let startPhase: CGFloat = -0.55

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * Self.bandRatio, height: geo.size.height)
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
    fileprivate func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - 本体

struct HomeDesignD: View {
    @State private var viewModel: HomeViewModel
    @State private var currentCardID: String? = nil
    @State private var showPlanListSheet = false
    @State private var showReasonSheet = false
    /// 着用記録中のカードid (記録中は全カードのボタンを無効化)
    @State private var markingWornID: String? = nil
    /// 理由シート内の買い足し導線から開くWebページ (シート内プッシュ)
    @State private var reasonWebLink: HomeWebLink? = nil
    /// サンドボックス単体では FavoritesStore が無いため、お気に入りは見た目のみのローカルトグル
    @State private var favoriteOverrides: [String: Bool] = [:]
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
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.white)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    sectionHeader
                    partnerRow
                    contentArea
                    actionsCard
                    Spacer().frame(height: 24)
                }
                .padding(.top, 20)
            }
        }
        .background(Color.gray.opacity(0.08))
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

    // MARK: - ヘッダー (既存ホームと同型)

    private var headerView: some View {
        ZStack {
            Text("ホーム")
                .font(.system(size: 18, weight: .semibold))
            HStack(spacing: 20) {
                Spacer()
                Button(action: { Haptic.selection() }) {
                    Image(systemName: "heart")
                }
                Button(action: { Haptic.selection() }) {
                    Image(systemName: "calendar")
                }
                Button(action: { Haptic.selection() }) {
                    Image(systemName: "questionmark.circle")
                }
            }
            .font(.system(size: 20))
            .foregroundStyle(.black)
        }
    }

    // MARK: - セクション見出し (明日のコーデ + 日付 + 天気バッジ)

    private var tomorrowShort: String {
        guard let daily else { return "" }
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        inFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inFmt.date(from: daily.target_date) else { return daily.target_date }
        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "ja_JP")
        outFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        outFmt.dateFormat = "M/d(E)"
        return outFmt.string(from: date)
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("明日のコーデ")
                .font(.system(size: 20, weight: .bold))
            if !tomorrowShort.isEmpty {
                Text(tomorrowShort)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let weather = daily?.weather {
                DailyMiniWeatherBadge(weather: weather)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 相棒コメント

    private var partnerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            PartnerIconImage(size: 44)
            DailyPartnerCommentBox(text: daily?.partner_comment ?? "明日のコーデ、3案そろえたよ。")
        }
        .padding(.horizontal, 24)
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
            errorCard
        } else {
            emptyCard
        }
    }

    private var cardCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
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

    private func planCard(_ card: DailyRecommendationItem, isBest: Bool) -> some View {
        VStack(spacing: 0) {
            KFImage(URL(string: card.image_url))
                .resizable()
                .placeholder { Color.gray.opacity(0.15) }
                .scaledToFill()
                .frame(width: 272, height: 340)
                .clipped()
                .overlay(alignment: .topLeading) {
                    if isBest {
                        DailyIchioshiBadge()
                            .padding(10)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    FavoriteToggleButton(isFavorite: isFavorite(card), size: 14) {
                        favoriteOverrides[card.id] = !isFavorite(card)
                    }
                    .padding(8)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // 既存ホームの「画像タップ → 詳細モーダル」パターンに合わせる
                    Haptic.selection()
                    withAnimation { currentCardID = card.id }
                    showReasonSheet = true
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(styleName(card))
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                    if usedItemsCount(for: card) > 0 {
                        Text("手持ち \(card.owned_items.count)/\(usedItemsCount(for: card))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                itemsRow(card)

                Button {
                    markWornTapped(card)
                } label: {
                    Text(markingWornID == card.id ? "記録中..." : "これにする")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(markingWornID != nil)
                .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 272)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// コーデの構成アイテムを手持ちと比較して1ブロックで表示する。
    /// 手持ち = 写真の重なり円形 / 未所持 = 集約バッジ「+n」(タップで構成リストへ)。
    /// 達成度セグメントバー + 状況別コピーで「あと少しで作れる」を伝える。
    @ViewBuilder
    private func itemsRow(_ card: DailyRecommendationItem) -> some View {
        let buys = buyCandidates(for: card)
        let total = card.owned_items.count + buys.count
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if !card.owned_items.isEmpty {
                    OwnedItemCircles(items: card.owned_items, size: 28, maxCount: 4, background: .white)
                }
                if !buys.isEmpty {
                    Button {
                        Haptic.selection()
                        withAnimation { currentCardID = card.id }
                        showReasonSheet = true
                    } label: {
                        BuyItemCircle(count: buys.count, size: 28)
                    }
                    .buttonStyle(.plain)
                    if card.owned_items.isEmpty {
                        Text(buys.joined(separator: "・"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            if total > 0 {
                CompletionSegments(owned: card.owned_items.count, total: total)
            }
            if !buys.isEmpty {
                Text(card.owned_items.isEmpty
                     ? "\(buys.count)点そろえると作れます"
                     : "あと\(buys.count)点そろえれば完成")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else if total > 0 {
                Text("手持ちだけで作れます")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var paginationRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(cards.indices, id: \.self) { i in
                    Circle()
                        .fill(i == currentIndex ? Color.black : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .animation(.easeOut(duration: 0.15), value: currentIndex)
            Text("\(currentIndex + 1) / \(cards.count)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Haptic.selection()
                showPlanListSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text("一覧で見る")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 状態表示 (ローディング / エラー / 空)

    // 実カルーセルと同一の構造(横ScrollView + contentMargins)に載せることで、
    // 固定幅カードのHStackが画面幅を超えてオーバーフローするのを防ぐ。
    private var loadingCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    skeletonCard
                }
            }
        }
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .scrollDisabled(true)
    }

    /// 実カード(planCard)と同じ骨格のスケルトン + シマー
    private var skeletonCard: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(width: 272, height: 340)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 120, height: 14)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 56, height: 10)
                }
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 28, height: 28)
                    }
                }
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 272)
        .background(.white)
        .shimmering()
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var errorCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 20))
                .foregroundStyle(Color.gray.opacity(0.5))
            VStack(alignment: .leading, spacing: 4) {
                Text("提案を読み込めませんでした")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                Button {
                    Task { await viewModel.refreshDailyRecommendation() }
                } label: {
                    Text("再試行する")
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                        .underline()
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 24)
    }

    private var emptyCard: some View {
        HStack {
            Text("明日の提案はまだありません")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 24)
    }

    // MARK: - 別ルート導線 (相棒カードの2ボタンと同型)

    private var actionsCard: some View {
        HStack(spacing: 10) {
            Button(action: { Haptic.selection() }) {
                Label("アイテムから", systemImage: "tshirt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Button(action: { Haptic.selection() }) {
                Label("相棒に相談", systemImage: "bubble.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 24)
    }

    // MARK: - 着用記録 (カード内「これにする」)

    private func markWornTapped(_ card: DailyRecommendationItem) {
        guard markingWornID == nil else { return }
        // closet 種別は pool_id がプールを指さないため着用記録の対象外
        if card.isCloset {
            toastManager.show("このコーデは記録対象外です")
            return
        }
        Haptic.impact(.medium)
        markingWornID = card.id
        Task { @MainActor in
            let ok = await viewModel.markWorn(item: card)
            markingWornID = nil
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
        NavigationStack {
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
                        // コーデの構成アイテムを手持ちと突き合わせた統一チェックリスト。
                        // ✓(手持ち) と +(買い足し) が同じリストに並ぶことで「比較」を伝える。
                        let buys = buyCandidateItems(for: card)
                        let total = card.owned_items.count + buys.count
                        if total > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline) {
                                    sectionLabel("コーデの構成アイテム")
                                    Spacer()
                                    Text("手持ち \(card.owned_items.count)/\(total)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                CompletionSegments(owned: card.owned_items.count, total: total)
                                VStack(spacing: 12) {
                                    ForEach(card.owned_items, id: \.item_id) { owned in
                                        ownedRow(owned)
                                    }
                                    ForEach(buys, id: \.self) { candidate in
                                        missingRow(candidate)
                                    }
                                }
                                .padding(.top, 4)
                                if buys.isEmpty {
                                    Text("手持ちのアイテムだけで作れます")
                                        .font(.system(size: 12, weight: .semibold))
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(card.owned_items.isEmpty
                                             ? "\(buys.count)点そろえると、このコーデがつくれます"
                                             : "あと\(buys.count)点そろえると、このコーデがつくれます")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("「探す」からZOZOTOWNの検索結果を開けます")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .navigationTitle("このコーデ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { showReasonSheet = false }
                }
            }
            .navigationDestination(item: $reasonWebLink) { link in
                WebViewContainer(url: link.url)
                    .navigationTitle("ZOZOTOWNで探す")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 一覧シート

    private var planListSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(daily?.recommendations ?? []) { item in
                        Button {
                            selectFromList(item)
                        } label: {
                            DailyGridImage(imageURL: item.image_url)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .navigationTitle("すべての提案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { showPlanListSheet = false }
                }
            }
        }
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
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black)
    }

    private func isFavorite(_ card: DailyRecommendationItem) -> Bool {
        favoriteOverrides[card.id] ?? card.is_favorite
    }

    private func styleName(_ card: DailyRecommendationItem) -> String {
        if !card.style.isEmpty { return card.style }
        if !card.vibe.isEmpty { return card.vibe }
        return "おすすめコーデ"
    }

    /// 買い足し候補 (ラベル + 推定スロット)
    private struct BuyCandidate: Hashable {
        let label: String
        let slot: String?
    }

    /// コーデで使っているが手持ちに無い (=買い足し候補) アイテム。
    /// missing_items を正とし (スロットは items 辞書との名寄せで推定)、
    /// items 辞書にだけ現れる使用アイテム (outer 等) を重複を除いて追加する。
    private func buyCandidateItems(for card: DailyRecommendationItem) -> [BuyCandidate] {
        func normalize(_ s: String) -> String {
            s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: "")
        }
        let ownedSlots = Set(card.owned_items.map(\.slot))
        var seen = Set(card.owned_items.map { normalize($0.label) })
        var result: [BuyCandidate] = []
        func append(_ label: String, slot: String?) {
            let key = normalize(label)
            guard !key.isEmpty,
                  !seen.contains(where: { $0.contains(key) || key.contains($0) }) else { return }
            seen.insert(key)
            result.append(.init(label: label, slot: slot))
        }
        func inferSlot(for label: String) -> String? {
            let key = normalize(label)
            return card.items.first { slot, name in
                guard !ownedSlots.contains(slot), let name, !name.isEmpty else { return false }
                let n = normalize(name)
                return n.contains(key) || key.contains(n)
            }?.key
        }
        for label in card.missing_items {
            append(label, slot: inferSlot(for: label))
        }
        let slotOrder = ["tops", "bottoms", "outer", "shoes", "bag", "accessory"]
        let orderedSlots = slotOrder.filter { card.items.keys.contains($0) }
            + card.items.keys.filter { !slotOrder.contains($0) }.sorted()
        for slot in orderedSlots where !ownedSlots.contains(slot) {
            if let name = card.items[slot] ?? nil {
                append(name, slot: slot)
            }
        }
        return result
    }

    private func buyCandidates(for card: DailyRecommendationItem) -> [String] {
        buyCandidateItems(for: card).map(\.label)
    }

    /// カードに表示する構成点数 = 手持ち + 買い足し候補の合計
    private func usedItemsCount(for card: DailyRecommendationItem) -> Int {
        card.owned_items.count + buyCandidates(for: card).count
    }

    private func slotDisplayName(_ slot: String) -> String {
        switch slot {
        case "tops": return "トップス"
        case "bottoms": return "ボトムス"
        case "outer": return "アウター"
        case "shoes": return "シューズ"
        case "bag": return "バッグ"
        case "accessory": return "小物"
        default: return slot
        }
    }

    // MARK: - 構成アイテム行 (理由シート)

    /// 手持ち行: 写真+✓バッジ / スロット名 / 「手持ち」
    private func ownedRow(_ owned: DailyOwnedItem) -> some View {
        HStack(spacing: 10) {
            CircleThumb(url: owned.image_url)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(Color.black)
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(owned.label)
                    .font(.system(size: 13))
                Text(slotDisplayName(owned.slot))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("手持ち")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    /// 買い足し行: 破線サムネ / スロット名 / 「探す」ピル (タップでZOZO検索)
    private func missingRow(_ candidate: BuyCandidate) -> some View {
        Button {
            openBuySearch(candidate.label)
        } label: {
            HStack(spacing: 10) {
                MissingItemThumb()
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.label)
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.leading)
                    if let slot = candidate.slot {
                        Text(slotDisplayName(slot))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                SearchPill()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 買い足し導線 (ZOZOTOWN検索)

    /// 理由シート内のチップから、シート内プッシュでZOZOTOWN検索を開く
    private func openBuySearch(_ label: String) {
        Haptic.selection()
        guard let url = zozoSearchURL(for: label) else { return }
        reasonWebLink = HomeWebLink(url: url)
    }

    /// ZOZOTOWN のアイテム検索URLを生成する。
    /// p_keyv は UTF-8 ではなく Shift_JIS 系のパーセントエンコードを期待するため
    /// (UTF-8 だと検索欄で文字化けする)、バックエンド closet_bridge_service と同じ仕様で
    /// Shift_JIS に変換してからエンコードする。
    private func zozoSearchURL(for label: String) -> URL? {
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        let genderKW = gender == .male ? "メンズ" : "レディース"
        var query = label
        if !query.contains(genderKW) {
            query += " " + genderKW
        }
        guard let data = query.data(using: .shiftJIS, allowLossyConversion: true), !data.isEmpty else {
            return URL(string: "https://zozo.jp/")
        }
        let encoded = data.map { byte -> String in
            switch byte {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F, 0x7E:
                return String(UnicodeScalar(byte))
            default:
                return String(format: "%%%02X", byte)
            }
        }.joined()
        return URL(string: "https://zozo.jp/search/?p_keyv=\(encoded)")
    }
}

#Preview("案D - 明日の提案ファーストビュー(IRODORI版)") {
    HomeDesignD(viewModel: HomeViewModel(
        apiClient: MockHomeClient(),
        dailyRecommendationClient: MockDailyRecommendationClient()
    ))
    .environment(MainTabViewModel())
}

// MARK: - ローディング(スケルトン)プレビュー

/// スケルトン確認用: 日次レコメンドを返さず、ローディング状態を維持するクライアント
private final class PendingDailyRecommendationClient: DailyRecommendationClientProtocol {
    func get(uid: String, gender: Gender, targetDate: String?) async throws -> Result<DailyRecommendationResponse, HTTPError> {
        try await Task.sleep(nanoseconds: 3_600_000_000_000)   // 1時間 (実質返らない)
        return .success(.mock())
    }

    func markWorn(uid: String, poolId: String, wornDate: String) async throws -> Result<WearMarkResponse, HTTPError> {
        .success(.init(status: "ok", pool_id: poolId, worn_date: wornDate))
    }
}

#Preview("案D - ローディング(シマー)") {
    HomeDesignD(viewModel: HomeViewModel(
        apiClient: MockHomeClient(),
        dailyRecommendationClient: PendingDailyRecommendationClient()
    ))
    .environment(MainTabViewModel())
}

// MARK: - 実API接続プレビュー

/// Preview プロセスの UserDefaults は実機アプリと別コンテナで空のため、
/// 未設定の場合のみ検証用の uid / 性別を書き込む (ログイン済み環境の値は上書きしない)。
/// ログイン中ユーザーのデータで確認したい場合は uid を実際の値に書き換える。
private func configureRealAPIPreviewUser() {
    let ud = UserDefaults.standard
    if (ud.string(forKey: UserDefaultsKey.userId.rawValue) ?? "").isEmpty {
        ud.set("ios-sandbox-preview", forKey: UserDefaultsKey.userId.rawValue)
    }
    if (ud.string(forKey: UserDefaultsKey.gender.rawValue) ?? "").isEmpty {
        // 推薦プールは性別で分かれるため、未設定 (=その他扱い) を避けて明示する
        ud.set(Gender.female.rawValue, forKey: UserDefaultsKey.gender.rawValue)
    }
}

/// 実通信は日次レコメンド GET と「これにする」の wear POST のみ。
/// 他セクションのクライアントは Mock 化し、本番 (Render) への不要な呼び出しを避ける。
/// 初回はサーバ側生成で数秒〜数十秒かかることがある (以降は日次キャッシュで高速)。
#Preview("案D - 実API接続(日次レコメンドのみ実通信)") {
    configureRealAPIPreviewUser()
    return HomeDesignD(viewModel: HomeViewModel(
        apiClient: MockHomeClient(),
        coordinateRecommendClient: MockCoordinateRecommendClient(),
        analyzeRecentCoordinateClient: MockAnalyzeRecentCoordinateClient(),
        closetClient: MockClosetClient(),
        deleteCoordinateClient: MockDeleteCoordinateClient(),
        dailyRecommendationClient: DailyRecommendationClient(),
        closetBridgeClient: MockClosetBridgeClient(),
        outfitCollageClient: MockOutfitCollageClient()
    ))
    .environment(MainTabViewModel())
}
