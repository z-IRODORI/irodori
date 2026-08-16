//
//  TomorrowPickSection.swift
//  irodori
//
//  ホームのヒーロー「明日のコーデ」セクション。
//  Sandbox/HomeDesignD で検証したデザインの本番部品化。
//  3案カルーセル + 構成アイテムの手持ち比較 (レシピ vs クローゼット) +
//  買い足し (ZOZOTOWN検索) 導線 + これにする (着用記録) を提供する。
//

import SwiftUI
import Kingfisher

// MARK: - 構成アイテム比較ロジック

fileprivate enum CoordComposition {
    struct BuyCandidate: Hashable {
        let label: String
        let slot: String?
    }

    static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: "")
    }

    /// コーデで使っているが手持ちに無い (=買い足し候補) アイテム。
    /// missing_items を正とし (スロットは items 辞書との名寄せで推定)、
    /// items 辞書にだけ現れる使用アイテム (outer 等) を重複を除いて追加する。
    static func buyCandidates(for card: DailyRecommendationItem) -> [BuyCandidate] {
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

    static func slotDisplayName(_ slot: String) -> String {
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

    /// ZOZOTOWN のアイテム検索URLを生成する。
    /// p_keyv は UTF-8 ではなく Shift_JIS 系のパーセントエンコードを期待するため
    /// (UTF-8 だと検索欄で文字化けする)、バックエンド closet_bridge_service と同じ仕様で
    /// Shift_JIS に変換してからエンコードする。
    static func zozoSearchURL(for label: String) -> URL? {
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

// MARK: - 小部品

/// 買い足し候補の集約バッジ (破線サークル + 「+n」)
fileprivate struct BuyCountBadge: View {
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
fileprivate struct SearchPill: View {
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

/// 翌日レスポンス: 「昨日の声、反映したよ」バッジ (フィードバックした翌日だけ出る)。
/// 相棒コメントボックスと同じ視覚言語のティール版。
fileprivate struct FeedbackAckBadge: View {
    let ack: DailyFeedbackAck

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.bubble.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("昨日の声、反映したよ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                Text(ack.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.teal.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.teal.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 構成リストの未所持サムネ (破線サークル=未所持の視覚言語)
fileprivate struct MissingItemThumb: View {
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

/// 理由シートの手持ちアイテム行で使う円形サムネ
fileprivate struct OwnedItemThumb: View {
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

/// 達成度セグメントバー。構成アイテム数ぶんの区画を手持ち数だけ塗り、
/// 「あと少しで完成」の感覚を一目で伝える。
fileprivate struct CompletionSegments: View {
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

// MARK: - シマー (メルカリ風スケルトン)

fileprivate struct ShimmerModifier: ViewModifier {
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
    fileprivate func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - セクション本体

struct TomorrowPickSection: View {
    let viewModel: HomeViewModel
    /// 地域バッジタップ (都道府県ピッカーの表示は HomeView 側が管理)
    let onLocationTap: () -> Void

    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(MainTabViewModel.self) private var tabViewModel
    @State private var currentCardID: String? = nil
    @State private var reasonItem: DailyRecommendationItem? = nil
    @State private var showPlanListSheet = false
    @State private var listPushItem: DailyRecommendationItem? = nil
    @State private var markingWornID: String? = nil
    /// 提案セット全体への「合っていない」フィードバック (確認ダイアログ + 送信中)
    @State private var showSetMismatchDialog = false
    @State private var isSendingSetMismatch = false
    /// 「これにする」直後の見送り画面 (決定の儀式)
    @State private var sendoffItem: DailyRecommendationItem? = nil
    /// 朝いち演出 (1日1回): false の間はカルーセルを隠し、フェードインで登場させる
    @State private var ritualRevealed = true
    /// 今日/明日/週末タブの選択下線をスライドさせる
    @Namespace private var scopeUnderlineNamespace
    #if DEBUG
    /// 開発ビルド専用: カルーセルの表示件数 (1〜9、リリースは常に3)
    @AppStorage("debug.pickCardLimit") private var debugCardLimit: Int = 3
    #endif

    private var cardDisplayLimit: Int {
        #if DEBUG
        return max(1, min(debugCardLimit, 9))
        #else
        return 3
        #endif
    }

    private var daily: DailyRecommendationResponse? { viewModel.dailyRecommendation }
    private var cards: [DailyRecommendationItem] {
        // 他タブが表示中のコーデ・自分の登録コーデを除いたリストから上位を表示
        Array(viewModel.displayRecommendations(for: viewModel.selectedPickScope).prefix(cardDisplayLimit))
    }
    private var currentIndex: Int { cards.firstIndex { $0.id == currentCardID } ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            scopeSegments
            sectionHeader
            #if DEBUG
            debugBar
            #endif
            // 翌日レスポンス: 昨日の👍👎への「反映したよ」バッジ
            if let ack = daily?.feedback_ack {
                FeedbackAckBadge(ack: ack)
                    .padding(.horizontal, 24)
            }
            if decidedPoolIdForCurrentTab != nil {
                decidedBanner
            } else if let planned = plannedForCurrentTab {
                // カレンダー側で予定したコーデをホームでも認知させる (ホーム⇄カレンダーの往復)
                plannedBanner(planned)
            }
            contentArea
            // クローゼットが少ないと手持ちベースのパーソナライズが効かないため、登録導線を出す
            if shouldShowItemNudge {
                itemRegistrationNudge
            }
        }
        .onAppear {
            playMorningRitualIfNeeded()
            // カレンダー側での予定追加/削除をタブ復帰時に反映する
            Task { await viewModel.refreshPlannedOutfits() }
        }
        .onChange(of: cards.count) { _, _ in
            playMorningRitualIfNeeded()
        }
        .onChange(of: viewModel.selectedPickScope) { _, _ in
            currentCardID = nil
        }
        .sheet(item: $sendoffItem) { item in
            DecisionSendoffView(
                item: item,
                partnerComment: daily?.partner_comment,
                weather: daily?.weather,
                scopeName: viewModel.selectedPickScope.displayName
            )
        }
        // コーデ詳細は半モーダルではなく全画面で見せる (画像・構成リストの視認性優先)
        .fullScreenCover(item: $reasonItem) { item in
            NavigationStack {
                TomorrowCompositionView(
                    item: item,
                    initialRating: viewModel.feedbackRating(for: item),
                    onFeedback: { rating, reasons in
                        await viewModel.sendFeedback(item: item, rating: rating, reasons: reasons)
                    },
                    onAddedToCalendar: { date in
                        viewModel.notePlanned(date: date, item: item, source: "home")
                    }
                )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") { reasonItem = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPlanListSheet) { planListSheet }
        .confirmationDialog(
            "表示中の\(cards.count)案を「合っていない」として記録し、別の提案に切り替えます",
            isPresented: $showSetMismatchDialog,
            titleVisibility: .visible
        ) {
            Button("合っていないと伝える", role: .destructive) {
                sendSetMismatch()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - セット全体のメタ行 (根拠キャプション + 「合っていない」)

    /// 左: 「あなたの◯回の記録から」等の根拠キャプション (サーバ生成)。
    /// カルーセル下の11ptグレーでは気付かれないため、カルーセル直上に黒字で置き
    /// 「この3案が何から選ばれたか」を先に伝える (バッジ化はしない)。
    /// 右: セットごと dislike して次の候補に切り替える逃げ道。
    private var setMetaRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if let caption = daily?.signal_caption, !caption.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .semibold))
                    Text(caption)
                        .font(.system(size: 12))
                        .lineSpacing(2)
                        .lineLimit(2)
                }
                .foregroundStyle(.black.opacity(0.75))
            }
            Spacer(minLength: 8)
            Button {
                Haptic.selection()
                showSetMismatchDialog = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsdown")
                        .font(.system(size: 10, weight: .semibold))
                    Text(isSendingSetMismatch ? "切り替え中..." : "全体的に合っていない")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSendingSetMismatch)
        }
        .padding(.horizontal, 24)
    }

    /// 表示中のカード全部に dislike (理由: 全体的に合っていない) を送り、次の候補に切り替える
    private func sendSetMismatch() {
        guard !isSendingSetMismatch, !cards.isEmpty else { return }
        isSendingSetMismatch = true
        let targets = cards
        Task { @MainActor in
            let ok = await viewModel.sendSetMismatchFeedback(items: targets)
            isSendingSetMismatch = false
            if ok {
                Haptic.notify(.success)
                withAnimation { currentCardID = nil }
                ToastManager.shared.show("教えてくれてありがとう。別の提案に切り替えるね", style: .normal)
            } else {
                Haptic.notify(.error)
                ToastManager.shared.show("送信に失敗しました。時間をおいて再度お試しください")
            }
        }
    }

    // MARK: - 今日/明日/週末 セグメント + 見出し (日付 + 地域 + 天気)

    private var currentTab: PickTab? {
        viewModel.pickTabs.first { $0.scope == viewModel.selectedPickScope }
    }

    /// 今日/明日/週末の切替を、カプセルではなく題字サイズのテキストタブで見せる。
    /// 「いま見ている提案がどの日のものか」がセクション見出しとして流し見でも伝わり、
    /// 具体的な日付・地域・天気は直下の sectionHeader が担う。
    private var scopeSegments: some View {
        HStack(alignment: .firstTextBaseline, spacing: 22) {
            ForEach(viewModel.pickTabs) { tab in
                let isSelected = tab.scope == viewModel.selectedPickScope
                Button {
                    Haptic.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.selectPickScope(tab.scope)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(tab.scope.displayName)
                            .font(.system(size: 22, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(isSelected ? Color.black : Color.black.opacity(0.3))
                        Group {
                            if isSelected {
                                Capsule()
                                    .fill(Color.black)
                                    .matchedGeometryEffect(id: "scope_underline", in: scopeUnderlineNamespace)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: 22, height: 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.label)のコーデ提案")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            if let tab = currentTab {
                Text(tab.shortDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            DailyLocationBadge(prefectureName: viewModel.currentPrefectureName, action: onLocationTap)
            if let weather = daily?.weather {
                DailyMiniWeatherBadge(weather: weather)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    #if DEBUG
    /// 開発ビルド専用: 表示件数の変更と、キャッシュ無視の再生成リロード
    private var debugBar: some View {
        HStack(spacing: 10) {
            Text("DEBUG")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.orange)
                .clipShape(Capsule())
            Menu {
                ForEach(1...9, id: \.self) { n in
                    Button("\(n)件") { debugCardLimit = n }
                }
            } label: {
                HStack(spacing: 3) {
                    Text("表示 \(cardDisplayLimit)件")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(Color.gray.opacity(0.35), lineWidth: 1))
            }
            Button {
                Haptic.impact(.light)
                Task { await viewModel.reloadDailyRecommendation() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                    Text("再生成")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(Color.gray.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoadingDailyRecommendation)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    #endif

    // MARK: - 朝いち演出 (1日1回だけ: フェードイン)

    private func playMorningRitualIfNeeded() {
        guard !cards.isEmpty else { return }
        let today = HomeViewModel.jstTodayString()
        let key = UserDefaultsKey.dailyRitualPlayedDate.rawValue
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)
        ritualRevealed = false
        withAnimation(.easeOut(duration: 0.7).delay(0.2)) {
            ritualRevealed = true
        }
    }

    // MARK: - 決定済み状態 (これにする済みのタブ)

    /// 表示中タブの対象日に「これにする」済みの pool_id
    private var decidedPoolIdForCurrentTab: String? {
        currentTab.flatMap { viewModel.decidedPoolId(forDate: $0.dateString) }
    }

    /// 表示中タブの対象日にカレンダーの予定コーデがあればそれ
    private var plannedForCurrentTab: CalendarOutfit? {
        currentTab.flatMap { viewModel.plannedOutfit(forDate: $0.dateString) }
    }

    private var decidedBanner: some View {
        Button {
            Haptic.impact(.soft)
            tabViewModel.selectedTab = .calendar
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.black)
                Text("\(viewModel.selectedPickScope.displayName)のコーデは決定ずみ。変えたくなったら選び直せるよ")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                calendarLinkLabel
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    /// カレンダー由来の予定コーデがある日のバナー。タップでカレンダータブへ
    private func plannedBanner(_ planned: CalendarOutfit) -> some View {
        Button {
            Haptic.impact(.soft)
            tabViewModel.selectedTab = .calendar
        } label: {
            HStack(spacing: 10) {
                KFImage(URL(string: planned.image_url))
                    .resizable()
                    .placeholder { Color.gray.opacity(0.15) }
                    .scaledToFill()
                    .frame(width: 36, height: 45)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.selectedPickScope.displayName)は予定コーデが決まってるよ")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("変えたいときは下の提案から選び直せるよ")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                calendarLinkLabel
            }
            .padding(10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    private var calendarLinkLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
            Text("カレンダー")
                .font(.system(size: 11, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.black)
    }

    // MARK: - アイテム登録促進 (クローゼットが少ないユーザー向け)

    /// クローゼット登録が少なく、手持ちベースのパーソナライズが効いていない状態か。
    /// 取得成功前 (hasLoadedCloset=false) は誤表示を避けるため出さない
    private var shouldShowItemNudge: Bool {
        !cards.isEmpty && viewModel.hasLoadedCloset && viewModel.closetItems.count < 3
    }

    private var itemRegistrationNudge: some View {
        let count = viewModel.closetItems.count
        return VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // 破線サークル = 「未所持/未登録」の視覚言語をここでも使う
                NoOwnedItemBadge(size: 40)
                VStack(alignment: .leading, spacing: 6) {
                    Text(count == 0 ? "手持ちアイテムを登録しよう" : "手持ちアイテムがまだ\(count)点だけ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("アイテムが増えるほど、手持ちの服で作れるコーデを優先して提案できるようになるよ。コーデを撮ると自動で登録される！")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            // ボタンはバッジ列に揃えず、カード全幅で中央に配置する。
            // ホームの他の主要ボタン (コーデ未登録の空状態カード) と同じスタイルに揃える
            Button {
                Haptic.impact(.soft)
                tabViewModel.shouldShowFirstTakePhotoOnHome = true
            } label: {
                HStack {
                    Text("コーデを撮って登録する")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 24)
    }

    // MARK: - コンテンツ (カルーセル / 状態)

    @ViewBuilder
    private var contentArea: some View {
        if !cards.isEmpty {
            setMetaRow
            cardCarousel
                .opacity(ritualRevealed ? 1 : 0)
                .offset(y: ritualRevealed ? 0 : 16)
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
                    // 挑戦枠のバッジは廃止 (バッジを増やさない方針)。
                    // is_discovery はカード題字 (ReasonHeadline) の teal で伝える
                    if isBest {
                        DailyIchioshiBadge()
                            .padding(10)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !card.isCloset {
                        favoriteButton(card)
                            .padding(8)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptic.selection()
                    withAnimation { currentCardID = card.id }
                    reasonItem = card
                }

            VStack(alignment: .leading, spacing: 8) {
                // なぜこのコーデか、をカードの題字そのもので伝える (バッジは使わない)。
                // ジャンル名は添え字に降格 (母集団がcasual偏重で、題字としては毎日同じ文字列になりがち)
                let headline = ReasonHeadline.line(
                    for: card,
                    signalCount: daily?.signal_count,
                    maxTemp: daily?.weather.max_temp,
                    scopeName: viewModel.selectedPickScope.displayName
                )
                VStack(alignment: .leading, spacing: 3) {
                    // 相棒アイコンを題字の左に添えて「相棒が選んだ一着」であることを伝える
                    // (天気下の相棒コメント行は廃止し、相棒の存在感はここへ集約)
                    HStack(spacing: 6) {
                        PartnerIconImage(size: 18)
                        Text(headline.text)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(headline.isDiscovery ? Color.teal : .black)
                            .lineLimit(1)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(styleName(card))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        if usedItemsCount(for: card) > 0 {
                            Text("手持ち \(card.owned_items.count)/\(usedItemsCount(for: card))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                // 題字の根拠の詳細 (サーバ生成。全文は構成シートで)
                // 理由なし/1行でも2行ぶんの高さを常に確保し、カード内の要素位置を揃える
                Text(card.reason ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .lineLimit(2, reservesSpace: true)
                itemsRow(card)

                Spacer(minLength: 0)

                let isDecided = card.pool_id == decidedPoolIdForCurrentTab
                Button {
                    markWornTapped(card)
                } label: {
                    HStack(spacing: 6) {
                        if isDecided {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(isDecided
                             ? "これで決まり"
                             : (markingWornID == card.id ? "記録中..." : wearButtonTitle))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isDecided ? Color.black.opacity(0.5) : .black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(markingWornID != nil || isDecided)
                .padding(.top, 4)
            }
            .padding(12)
        }
        // 種類 (理由の行数・手持ち有無・キャプション有無) によらず高さを統一する
        // (548 + 題字/添え字の2段化ぶん12pt。skeletonCard と同値を保つこと)
        .frame(width: 272, height: 560, alignment: .top)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .contextMenu {
            // closet 種別 (クローゼットから作ったコーデ) も評価対象
            Button(role: .destructive) {
                quickDislike(card)
            } label: {
                Label("このコーデに興味がない", systemImage: "hand.thumbsdown")
            }
        }
    }

    private func favoriteButton(_ card: DailyRecommendationItem) -> some View {
        let kind = card.kindEnum
        let isFav = favoritesStore.isFavoriteRespectingSession(
            kind: kind,
            targetId: card.pool_id,
            fallback: card.is_favorite
        )
        return FavoriteToggleButton(isFavorite: isFav, size: 14) {
            Task {
                await favoritesStore.setFavorite(
                    !isFav,
                    kind: kind,
                    targetId: card.pool_id,
                    imageURL: card.image_url
                )
            }
        }
    }

    /// コーデの構成アイテムを手持ちと比較して1ブロックで表示する。
    /// 手持ち = 写真の重なり円形 / 未所持 = 集約バッジ「+n」(タップで構成リストへ)。
    @ViewBuilder
    private func itemsRow(_ card: DailyRecommendationItem) -> some View {
        let buys = CoordComposition.buyCandidates(for: card)
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
                        reasonItem = card
                    } label: {
                        BuyCountBadge(count: buys.count, size: 28)
                    }
                    .buttonStyle(.plain)
                    if card.owned_items.isEmpty {
                        Text(buys.map(\.label).joined(separator: "・"))
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

    private var skeletonCard: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(width: 272, height: 340)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 150, height: 14)
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 90, height: 10)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 56, height: 10)
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 170, height: 10)
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 28, height: 28)
                    }
                }
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 272, height: 560, alignment: .top)
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
            Text("\(viewModel.selectedPickScope.displayName)の提案はまだありません")
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

    // MARK: - 着用記録 (これにする → 見送りの儀式)

    private func markWornTapped(_ card: DailyRecommendationItem) {
        guard markingWornID == nil else { return }
        // closet 種別は pool_id がプールを指さないため着用記録の対象外
        if card.isCloset {
            ToastManager.shared.show("このコーデは記録対象外です")
            return
        }
        Haptic.impact(.medium)
        markingWornID = card.id
        Task { @MainActor in
            let ok = await viewModel.markWorn(item: card)
            markingWornID = nil
            if ok {
                Haptic.notify(.success)
                if let tab = currentTab {
                    viewModel.recordDecision(poolId: card.pool_id, targetDate: tab.dateString)
                }
                // 決定の直後を無音にしない: トーストではなく見送り画面で送り出す
                sendoffItem = card
            } else {
                Haptic.notify(.error)
                ToastManager.shared.show("記録に失敗しました。時間をおいて再度お試しください")
            }
        }
    }

    /// カード長押しからのワンタップ「興味なし」(理由なし送信)。
    /// サーバでテイスト負シグナル+候補除外に反映され、表示からも即時消える。
    private func quickDislike(_ card: DailyRecommendationItem) {
        Haptic.impact(.light)
        Task { @MainActor in
            let ok = await viewModel.sendFeedback(item: card, rating: .dislike)
            if ok {
                Haptic.notify(.success)
                ToastManager.shared.show("このようなコーデの表示を減らします", style: .normal)
                withAnimation { currentCardID = nil }
            } else {
                ToastManager.shared.show("送信に失敗しました。時間をおいて再度お試しください")
            }
        }
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
                            Haptic.selection()
                            // カルーセル対象 (先頭3件) ならスナップ位置も合わせる
                            if cards.contains(where: { $0.id == item.id }) {
                                currentCardID = item.id
                            }
                            listPushItem = item
                        } label: {
                            DailyGridImage(imageURL: item.image_url)
                                // コーデに使っている手持ちアイテムを丸アイコンで右上に表示
                                // (◯ = 使える手持ちアイテム / 破線 = 手持ちと一致なし)
                                .overlay(alignment: .topTrailing) {
                                    if item.kindEnum == .pool {
                                        Group {
                                            if !item.owned_items.isEmpty {
                                                OwnedItemCircles(items: item.owned_items, size: 20)
                                            } else {
                                                NoOwnedItemBadge(size: 20)
                                            }
                                        }
                                        .padding(6)
                                    }
                                }
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
            .navigationDestination(item: $listPushItem) { item in
                TomorrowCompositionView(
                    item: item,
                    initialRating: viewModel.feedbackRating(for: item),
                    onFeedback: { rating, reasons in
                        await viewModel.sendFeedback(item: item, rating: rating, reasons: reasons)
                    },
                    onAddedToCalendar: { date in
                        viewModel.notePlanned(date: date, item: item, source: "home")
                    }
                )
            }
        }
    }

    // MARK: - ヘルパー

    /// 着るボタンの文言。対象日が伝わるようタブに合わせて変える (今日着る / 明日着る / 週末に着る)
    private var wearButtonTitle: String {
        switch viewModel.selectedPickScope {
        case .today: return "今日着る"
        case .tomorrow: return "明日着る"
        case .weekend: return "週末に着る"
        }
    }

    private func styleName(_ card: DailyRecommendationItem) -> String {
        if !card.style.isEmpty { return card.style }
        if !card.vibe.isEmpty { return card.vibe }
        return "おすすめコーデ"
    }

    private func usedItemsCount(for card: DailyRecommendationItem) -> Int {
        card.owned_items.count + CoordComposition.buyCandidates(for: card).count
    }
}

// MARK: - 構成アイテムビュー (このコーデの理由 + レシピ vs クローゼット)

fileprivate struct TomorrowCompositionView: View {
    let item: DailyRecommendationItem
    var initialRating: PickFeedbackRating? = nil
    /// フィードバック送信 (VM の sendFeedback へ委譲)。nil なら評価UI非表示
    var onFeedback: ((PickFeedbackRating, [String]) async -> Bool)? = nil
    /// 「カレンダーに追加」成功時 (追加した日付 YYYY-MM-DD)。nil なら追加ボタン非表示
    var onAddedToCalendar: ((String) -> Void)? = nil

    /// 買い足し導線から開くWebページ (ナビゲーションスタック内プッシュ)
    @State private var webLink: HomeWebLink? = nil
    @State private var showAddToCalendar = false
    @State private var rating: PickFeedbackRating? = nil
    @State private var showDislikeReasons = false
    @State private var selectedReasons: Set<String> = []
    @State private var isSendingFeedback = false
    @Environment(\.dismiss) private var dismiss

    private static let dislikeReasonOptions = [
        "色が好みじゃない", "系統が違う", "季節に合わない", "手持ちと合わせにくい",
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // コーデ画像: どのコーデの詳細かを最初に見せる。
                // 全身 (靴まで) が切れないよう fit 表示とし、左右の余白は薄グレーで馴染ませる
                KFImage(URL(string: item.image_url))
                    .resizable()
                    .placeholder { Color.gray.opacity(0.15) }
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(styleName)
                    .font(.system(size: 20, weight: .bold))
                if item.is_discovery {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("いつもと違う系統の挑戦枠です")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.teal)
                }
                if let reason = item.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 14))
                        .lineSpacing(6)
                } else if !item.vibe.isEmpty {
                    Text(item.vibe)
                        .font(.system(size: 14))
                        .lineSpacing(6)
                }
                compositionList
                // 気に入ったら先の日の予定にストックできる (カレンダー詳細と同じ導線をホームにも)。
                // closet 種別はカレンダー側の詳細取得がプール前提のため対象外
                if !item.isCloset, onAddedToCalendar != nil {
                    addToCalendarButton
                }
                // closet 種別 (クローゼットから作ったコーデ) も評価対象
                if onFeedback != nil {
                    feedbackSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .onAppear {
            if rating == nil { rating = initialRating }
        }
        .navigationTitle("コーデ詳細")
        .navigationBarTitleDisplayMode(.inline)
        // medium ディテントのシート内に push すると Web ページが画面半分しか使えないため、
        // 全画面カバーで開いて表示領域を最大化する
        .fullScreenCover(item: $webLink) { link in
            WebViewContainer(url: link.url)
        }
        .sheet(isPresented: $showAddToCalendar) {
            AddToCalendarSheet(
                kind: item.kind,
                targetId: item.pool_id,
                imageURL: item.image_url,
                source: "home",
                onSaved: { date in onAddedToCalendar?(date) }
            )
            .presentationDetents([.height(300)])
        }
    }

    // 予定コーデとしてカレンダーにストックする (カレンダー/お気に入りの詳細と同じ導線)
    private var addToCalendarButton: some View {
        Button {
            Haptic.impact(.medium)
            showAddToCalendar = true
        } label: {
            Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var styleName: String {
        if !item.style.isEmpty { return item.style }
        if !item.vibe.isEmpty { return item.vibe }
        return "おすすめコーデ"
    }

    // コーデの構成アイテムを手持ちと突き合わせた統一チェックリスト。
    // ✓(手持ち) と +(買い足し) が同じリストに並ぶことで「比較」を伝える。
    @ViewBuilder
    private var compositionList: some View {
        let buys = CoordComposition.buyCandidates(for: item)
        let total = item.owned_items.count + buys.count
        if total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("コーデの構成アイテム")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("手持ち \(item.owned_items.count)/\(total)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                CompletionSegments(owned: item.owned_items.count, total: total)
                VStack(spacing: 12) {
                    ForEach(item.owned_items, id: \.item_id) { owned in
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
                        Text(item.owned_items.isEmpty
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

    /// 手持ち行: 写真+✓バッジ / スロット名 / 「手持ち」
    private func ownedRow(_ owned: DailyOwnedItem) -> some View {
        HStack(spacing: 10) {
            OwnedItemThumb(url: owned.image_url)
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
                Text(CoordComposition.slotDisplayName(owned.slot))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("手持ち")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - フィードバック (パーソナライズ改善)

    @ViewBuilder
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("この提案は好みでしたか？")
                .font(.system(size: 15, weight: .semibold))
            HStack(spacing: 10) {
                thumbButton(.like, icon: "hand.thumbsup")
                thumbButton(.dislike, icon: "hand.thumbsdown")
            }
            if showDislikeReasons {
                Text("近い理由があれば教えてください（任意）")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(Self.dislikeReasonOptions, id: \.self) { reason in
                        reasonChip(reason)
                    }
                }
                HStack(spacing: 14) {
                    Button {
                        submitDislike(reasons: Array(selectedReasons))
                    } label: {
                        Text(isSendingFeedback ? "送信中..." : "送信")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(.black)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendingFeedback)
                    Button {
                        submitDislike(reasons: [])
                    } label: {
                        Text("スキップして送信")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendingFeedback)
                }
            } else if rating == .like {
                Text("ありがとうございます。今後の提案に反映します")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func thumbButton(_ value: PickFeedbackRating, icon: String) -> some View {
        let isSelected = rating == value
        return Button {
            Haptic.selection()
            if value == .like {
                submitLike()
            } else {
                rating = .dislike
                showDislikeReasons = true
            }
        } label: {
            Image(systemName: isSelected ? icon + ".fill" : icon)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? .white : .black)
                .frame(width: 48, height: 40)
                .background(isSelected ? Color.black : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(isSelected ? 0 : 0.3), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isSendingFeedback || (value == .like && rating == .like))
    }

    private func reasonChip(_ reason: String) -> some View {
        let isSelected = selectedReasons.contains(reason)
        return Button {
            Haptic.selection()
            if isSelected {
                selectedReasons.remove(reason)
            } else {
                selectedReasons.insert(reason)
            }
        } label: {
            Text(reason)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.black : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(isSelected ? 0 : 0.35), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func submitLike() {
        guard let onFeedback, rating != .like else { return }
        showDislikeReasons = false
        isSendingFeedback = true
        Task { @MainActor in
            let ok = await onFeedback(.like, [])
            isSendingFeedback = false
            if ok {
                rating = .like
                Haptic.notify(.success)
                ToastManager.shared.show("フィードバックを反映しました", style: .normal)
            } else {
                rating = initialRating
                ToastManager.shared.show("送信に失敗しました。時間をおいて再度お試しください")
            }
        }
    }

    private func submitDislike(reasons: [String]) {
        guard let onFeedback else { return }
        isSendingFeedback = true
        Task { @MainActor in
            let ok = await onFeedback(.dislike, reasons)
            isSendingFeedback = false
            if ok {
                Haptic.notify(.success)
                ToastManager.shared.show("このようなコーデの表示を減らします", style: .normal)
                dismiss()
            } else {
                ToastManager.shared.show("送信に失敗しました。時間をおいて再度お試しください")
            }
        }
    }

    /// 買い足し行: 破線サムネ / スロット名 / 「探す」ピル (タップでZOZO検索)
    private func missingRow(_ candidate: CoordComposition.BuyCandidate) -> some View {
        Button {
            Haptic.selection()
            if let url = CoordComposition.zozoSearchURL(for: candidate.label) {
                webLink = HomeWebLink(url: url)
            }
        } label: {
            HStack(spacing: 10) {
                MissingItemThumb()
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.label)
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.leading)
                    if let slot = candidate.slot {
                        Text(CoordComposition.slotDisplayName(slot))
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
}

#Preview("明日のコーデセクション") {
    let vm = HomeViewModel(
        apiClient: MockHomeClient(),
        dailyRecommendationClient: MockDailyRecommendationClient()
    )
    return ScrollView {
        TomorrowPickSection(viewModel: vm, onLocationTap: {})
            .padding(.top, 20)
    }
    .background(Color.gray.opacity(0.08))
    .environment(MainTabViewModel())
    .environment(FavoritesStore())
    .task { await vm.onAppear() }
}
