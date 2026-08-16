//
//  OutfitPlannerView.swift
//  irodori
//
//  まとめて提案: 1週間 / 1ヶ月 / カスタム日数分のコーデを一括提案し、
//  日ごとに候補から選び直し・除外して納得したら「この内容でカレンダーに追加」で
//  予定コーデ (calendar_outfits) へ一括保存する。承認するまで保存しない。
//
//  2026-08: Sandbox (WeeklyPlannerSandbox) で検証した週間プランナー体験を本番化。
//   - 生成待ち = 配り演出 (白カードのデッキ + 相棒の実況)
//   - 10日以下は裏向きカードの開封リビール (「一気に開ける」を選ぶと次回から縮退)
//   - 週テーマ + 相棒コメント + 根拠バッジのヘッダー (サーバの週ナラティブ)
//   - 入替のブラインド巡回を廃止し、軸ラベル (堅実/挑戦/気分転換) 付きの候補シートへ
//   - 保存後は栞 (サムネイルが順に綴じられる完成儀式) を見せてからカレンダーへ戻る
//  表示は日数で自動切替: 10日以下 = 縦の日カードリスト / 11日以上 = 週グリッド。
//

import SwiftUI
import Kingfisher

// MARK: - ViewModel

@MainActor
@Observable
final class OutfitPlannerViewModel {
    enum Period: String, CaseIterable, Identifiable {
        case week = "1週間"
        case month = "1ヶ月"
        case custom = "カスタム"
        var id: String { rawValue }
    }

    enum Phase {
        case setup       // 条件設定
        case dealing     // 生成待ち (配り演出)
        case revealing   // 開封リビール (10日以下のみ)
        case reviewing   // 候補から選ぶ・除外して確定
    }

    struct PlanDayState: Identifiable {
        let date: String                            // YYYY-MM-DD
        let weather: DailyRecommendationWeather?
        var candidates: [OutfitPlanCandidate]       // [本命, 入替候補...]
        let dayLine: String?                        // その日のひとこと (週ナラティブ or 理由文)
        var selectedIndex: Int = 0
        var isExcluded: Bool = false
        var hasExistingPlan: Bool = false
        var id: String { date }
        var selectedCandidate: OutfitPlanCandidate {
            candidates[min(selectedIndex, candidates.count - 1)]
        }
        var selected: DailyRecommendationItem { selectedCandidate.item }
    }

    var period: Period = .week
    var customDays: Int = 5
    var startDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    var phase: Phase = .setup
    var isLoading = false
    var isSaving = false
    var days: [PlanDayState] = []

    // 相棒の語り (サーバの週ナラティブ。旧サーバ応答では nil → 表示しない)
    var weekTitle: String?
    var weekComment: String?
    var planAck: String?
    var signalCaption: String?
    var speakingStyle: String = "normal"

    // 演出の状態
    var revealedDates: Set<String> = []
    var dealtCount: Int = 0
    var narrationIndex: Int = 0

    private var dealingTask: Task<Void, Never>?

    var daysCount: Int {
        switch period {
        case .week: return 7
        case .month: return 30
        case .custom: return customDays
        }
    }

    var includedCount: Int { days.filter { !$0.isExcluded }.count }

    /// 開封リビールの適用条件: 10日以下 かつ 「一気に開ける」で縮退していない
    var revealApplies: Bool {
        days.count <= 10
            && !UserDefaults.standard.bool(forKey: UserDefaultsKey.plannerRevealCollapsed.rawValue)
    }

    var allRevealed: Bool { !days.isEmpty && revealedDates.count >= days.count }

    private let planClient: RecommendationPlanClientProtocol
    private let calendarOutfitClient: CalendarOutfitClientProtocol
    private let uid: String

    init(
        planClient: RecommendationPlanClientProtocol = RecommendationPlanClient(),
        calendarOutfitClient: CalendarOutfitClientProtocol = CalendarOutfitClient()
    ) {
        self.planClient = planClient
        self.calendarOutfitClient = calendarOutfitClient
        self.uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
    }

    func generate() async {
        guard !isLoading else { return }
        isLoading = true
        revealedDates = []
        dealtCount = 0
        narrationIndex = 0
        phase = .dealing
        let startedAt = Date()

        // 配り演出: 白カードが1枚ずつ積まれ、実況が進む (生成待ちを第一幕にする)
        dealingTask?.cancel()
        let targetCount = daysCount
        dealingTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 550_000_000)
                guard let self, self.phase == .dealing else { return }
                tick += 1
                self.dealtCount = min(tick, min(targetCount, 7))   // 積むのは表示上7枚まで
                self.narrationIndex = min(tick / 2, PlannerVoice.dealingLines.count - 1)
            }
        }
        defer {
            dealingTask?.cancel()
            isLoading = false
        }

        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        let prefectureCode = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let startString = formatter.string(from: startDate)

        let result = try? await planClient.plan(
            uid: uid, gender: gender, days: daysCount,
            startDate: startString, prefectureCode: prefectureCode,
            candidatesPerDay: 15   // 候補シートで選べる幅を確保 (本命1 + 入替14)
        )
        guard let result, case .success(let response) = result, !response.days.isEmpty else {
            ToastManager.shared.show("コーデの提案に失敗しました。時間をおいて再度お試しください")
            phase = .setup
            return
        }

        // 既に予定がある日を調べ、デフォルト除外にする (上書き事故防止。トグルで含められる)
        let existingDates = await fetchExistingPlannedDates(in: response.days.map(\.date))

        days = response.days.map { day in
            let exists = existingDates.contains(day.date)
            return PlanDayState(
                date: day.date,
                weather: day.weather,
                candidates: [day.item] + day.alternates,
                dayLine: day.day_line,
                selectedIndex: 0,
                isExcluded: exists,
                hasExistingPlan: exists
            )
        }
        weekTitle = response.week_title
        weekComment = response.week_comment
        planAck = response.plan_ack
        signalCaption = response.signal_caption
        speakingStyle = response.speaking_style ?? "normal"

        // 配り演出が一瞬で消えないよう最低尺だけ確保する
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < 1.4 {
            try? await Task.sleep(nanoseconds: UInt64((1.4 - elapsed) * 1_000_000_000))
        }

        if revealApplies {
            phase = .revealing
            Haptic.impact(.soft)
        } else {
            revealedDates = Set(days.map(\.date))
            phase = .reviewing
        }
    }

    private func fetchExistingPlannedDates(in dates: [String]) async -> Set<String> {
        var months = Set<String>()
        for date in dates {
            months.insert(String(date.prefix(7)))   // "YYYY-MM"
        }
        var existing = Set<String>()
        for ym in months {
            let parts = ym.split(separator: "-")
            guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { continue }
            if let result = try? await calendarOutfitClient.list(uid: uid, year: year, month: month),
               case .success(let response) = result {
                existing.formUnion(response.items.map(\.date))
            }
        }
        return existing
    }

    // MARK: 開封

    func reveal(_ date: String) {
        guard !revealedDates.contains(date) else { return }
        Haptic.impact(.light)
        revealedDates.insert(date)
        if allRevealed { Haptic.notify(.success) }
    }

    /// 「一気に開ける」。選んだ人は儀式を求めていないため、次回から開封済みで着地する
    func revealAllAndCollapseNext() {
        Haptic.impact(.medium)
        revealedDates = Set(days.map(\.date))
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.plannerRevealCollapsed.rawValue)
    }

    func proceedToReview() {
        revealedDates = Set(days.map(\.date))
        phase = .reviewing
    }

    // MARK: 選択・除外

    func select(date: String, index: Int) {
        guard let dayIndex = days.firstIndex(where: { $0.date == date }),
              index < days[dayIndex].candidates.count else { return }
        Haptic.selection()
        days[dayIndex].selectedIndex = index
    }

    func toggleExclude(_ date: String) {
        guard let index = days.firstIndex(where: { $0.date == date }) else { return }
        days[index].isExcluded.toggle()
    }

    func reset() {
        days = []
        weekTitle = nil
        weekComment = nil
        planAck = nil
        signalCaption = nil
        phase = .setup
    }

    /// 承認された日をまとめて予定コーデとして保存。成功時は保存件数を返す
    func save() async -> Int? {
        let included = days.filter { !$0.isExcluded }
        guard !included.isEmpty, !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }

        let items = included.map { day in
            CalendarOutfit(
                date: day.date,
                kind: day.selected.kindEnum == .self ? "self" : "pool",
                target_id: day.selected.pool_id,
                image_url: day.selected.image_url,
                source: "plan"
            )
        }
        guard let result = try? await calendarOutfitClient.bulk(uid: uid, items: items, overwrite: true),
              case .success(let response) = result else {
            ToastManager.shared.show("カレンダーへの追加に失敗しました")
            return nil
        }
        return response.saved_count
    }
}

// MARK: - 相棒の声 (端末内定数)

enum PlannerVoice {
    /// 配り演出の実況 (進行段階ごと)。生成前は話し方設定が届いていないため中立の口調
    static let dealingLines = [
        "週間予報をチェック中…",
        "これまでの記録を読み返し中…",
        "1日ずつ組み合わせ中…",
        "もうすぐ出来上がり…",
    ]

    /// 栞の締めの一言 (サーバの speaking_style に合わせて声を割らない)
    static func closing(for styleKey: String) -> String {
        switch styleKey {
        case "gentle": return "きっと素敵な一週間になりますよ。"
        case "spicy": return "決めたからには、ちゃんと着なよ。"
        case "kansai": return "ほな、ええ一週間にしよか。"
        case "cool": return "以上。あとは着るだけ。"
        case "gal": return "楽しみにしてて〜！"
        case "ojou": return "よい一週間になりますように。"
        default: return "この調子でいこう。"
        }
    }
}

// MARK: - 候補の軸ラベル (サーバの alt_tag)

private enum PlanAxis: String {
    case steady, challenge, change

    var label: String {
        switch self {
        case .steady: return "堅実"
        case .challenge: return "挑戦"
        case .change: return "気分転換"
        }
    }

    var caption: String {
        switch self {
        case .steady: return "手持ちで組める"
        case .challenge: return "いつもと違う系統"
        case .change: return "別の切り口"
        }
    }

    var icon: String {
        switch self {
        case .steady: return "checkmark.seal"
        case .challenge: return "sparkles"
        case .change: return "arrow.triangle.2.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .steady: return .black
        case .challenge: return .teal
        case .change: return .orange
        }
    }
}

// MARK: - View

struct OutfitPlannerView: View {
    @Binding var path: [ViewType]
    @State private var viewModel = OutfitPlannerViewModel()
    /// 候補シートを開いている日付 (nil = 非表示)
    @State private var choiceDate: PlannerSheetDate? = nil
    /// 保存後の栞 (完成儀式)。表示中はタップ or 自動でカレンダーへ戻る
    @State private var savedCount: Int? = nil

    var body: some View {
        Group {
            switch viewModel.phase {
            case .setup: setupView
            case .dealing: dealingView
            case .revealing: revealView
            case .reviewing: resultView
            }
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle("まとめて提案")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $choiceDate) { sheetDate in
            PlanChoiceSheet(
                viewModel: viewModel,
                date: sheetDate.value,
                onClose: { choiceDate = nil }
            )
            .presentationDetents([.medium, .large])
        }
        .overlay {
            if let count = savedCount {
                bookmarkOverlay(savedCount: count)
            }
        }
    }

    // MARK: 条件設定

    private var setupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("期間を選ぶと、相棒がその日数分のコーデをまとめて提案します。気に入らない日は候補からの選び直しや除外ができます。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 16) {
                    Text("期間")
                        .font(.system(size: 14, weight: .bold))
                    HStack(spacing: 8) {
                        ForEach(OutfitPlannerViewModel.Period.allCases) { period in
                            segment(period.rawValue, selected: viewModel.period == period) {
                                viewModel.period = period
                            }
                        }
                    }

                    if viewModel.period == .custom {
                        HStack(spacing: 8) {
                            customChip("3日", days: 3)
                            customChip("5日", days: 5)
                            customChip("10日", days: 10)
                            customChip("2週間", days: 14)
                        }
                        Stepper(
                            "\(viewModel.customDays)日分",
                            value: $viewModel.customDays.animation(),
                            in: 2...31
                        )
                        .font(.system(size: 14))
                    }

                    Divider()

                    HStack {
                        Text("開始日")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $viewModel.startDate,
                            in: Calendar.current.startOfDay(for: Date())...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .tint(.black)
                    }
                }
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
        }
        .safeAreaInset(edge: .bottom) {
            ctaBar(title: "コーデを考えてもらう（\(viewModel.daysCount)日分）", enabled: !viewModel.isLoading) {
                Task { await viewModel.generate() }
            }
        }
    }

    // MARK: 配り演出 (生成待ち)

    private var dealingView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                ForEach(0..<max(viewModel.dealtCount, 1), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white)
                        .frame(width: 150, height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 3)
                        .rotationEffect(.degrees(Double(index % 5 - 2) * 2.2))
                        .offset(x: CGFloat(index % 5 - 2) * 5, y: CGFloat(-index) * 3)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(height: 240)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: viewModel.dealtCount)

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    PartnerIconImage(size: 40)
                    DailyPartnerCommentBox(
                        text: PlannerVoice.dealingLines[
                            min(viewModel.narrationIndex, PlannerVoice.dealingLines.count - 1)
                        ]
                    )
                }
                Text("\(viewModel.daysCount)日分を準備中")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 開封リビール (10日以下)

    private var revealView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                weekHeader

                Text(viewModel.allRevealed
                     ? "ぜんぶ開けました"
                     : "カードをタップしてめくってください（\(viewModel.revealedDates.count) / \(viewModel.days.count)）")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(viewModel.days) { day in
                        revealCard(day)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 10) {
                    if !viewModel.allRevealed {
                        Button {
                            viewModel.revealAllAndCollapseNext()
                        } label: {
                            Text("一気に開ける")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(.white)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        Haptic.impact(.medium)
                        viewModel.proceedToReview()
                    } label: {
                        Text("決めていく")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .background(.white)
        }
    }

    /// 裏向き/表向きの2面を同じ 3:4 の枠に重ねる (枠は Color.clear で作りセル高を揃える)
    private func revealCard(_ day: OutfitPlannerViewModel.PlanDayState) -> some View {
        let revealed = viewModel.revealedDates.contains(day.date)
        let item = day.selected
        return Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                ZStack {
                    revealCardBack(day, isDiscovery: item.is_discovery)
                        .opacity(revealed ? 0 : 1)
                        .rotation3DEffect(.degrees(revealed ? 180 : 0), axis: (x: 0, y: 1, z: 0))

                    revealCardFront(day, item: item)
                        .opacity(revealed ? 1 : 0)
                        .rotation3DEffect(.degrees(revealed ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.45), value: revealed)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.reveal(day.date) }
    }

    /// 裏面: 日付・曜日・天気だけを印字する (発見枠は「?」)
    private func revealCardBack(_ day: OutfitPlannerViewModel.PlanDayState, isDiscovery: Bool) -> some View {
        VStack(spacing: 3) {
            Text(monthDayLabel(day.date))
                .font(.system(size: 15, weight: .bold))
            Text(weekdayLabel(day.date))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if let weather = day.weather {
                WxWeatherIcon(condition: weather.condition, size: 18)
                    .padding(.top, 4)
                Text(DailyWeatherDisplay.compactCondition(weather.condition))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(weather.min_temp)〜\(weather.max_temp)°")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            if isDiscovery {
                Text("?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.teal)
                    .padding(.top, 2)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 表面: コーデ写真 (枠いっぱいにクロップ)
    private func revealCardFront(_ day: OutfitPlannerViewModel.PlanDayState, item: DailyRecommendationItem) -> some View {
        Color.gray.opacity(0.12)
            .overlay {
                KFImage(URL(string: item.image_url))
                    .placeholder { Color.gray.opacity(0.12) }
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                if item.is_discovery {
                    discoveryBadge
                        .padding(5)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text("\(monthDayLabel(day.date))(\(weekdayLabel(day.date)))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .padding(5)
            }
    }

    // MARK: 提案レビュー

    private var resultView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                weekHeader
                    .padding(.top, 8)

                HStack {
                    Text("気に入らない日は候補からの選び直し・除外ができます")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Haptic.impact(.soft)
                        viewModel.reset()
                    } label: {
                        Text("条件を変える")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black)
                            .underline()
                    }
                }

                if viewModel.days.count <= 10 {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.days) { day in
                            dayCard(day)
                        }
                    }
                } else {
                    planGrid
                }

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 20)
        }
        .safeAreaInset(edge: .bottom) {
            ctaBar(
                title: "この内容でカレンダーに追加（\(viewModel.includedCount)日分）",
                enabled: viewModel.includedCount > 0 && !viewModel.isSaving
            ) {
                Task {
                    if let count = await viewModel.save() {
                        Haptic.notify(.success)
                        withAnimation(.easeOut(duration: 0.25)) {
                            savedCount = count   // 栞を見せてからカレンダーへ戻る
                        }
                    }
                }
            }
        }
    }

    /// 週テーマ + 相棒コメント + 根拠バッジ (サーバの週ナラティブ。無ければ出さない)
    @ViewBuilder
    private var weekHeader: some View {
        if let title = viewModel.weekTitle, let comment = viewModel.weekComment {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))

                HStack(alignment: .top, spacing: 10) {
                    PartnerIconImage(size: 36)
                    DailyPartnerCommentBox(text: comment)
                }

                if let ack = viewModel.planAck, !ack.isEmpty {
                    Text(ack)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                if let caption = viewModel.signalCaption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06), lineWidth: 1))
        }
    }

    private var discoveryBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .semibold))
            Text("挑戦")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.teal)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.teal.opacity(0.35), lineWidth: 0.8))
    }

    // 日カード (10日以下のリスト表示)
    private func dayCard(_ day: OutfitPlannerViewModel.PlanDayState) -> some View {
        let item = day.selected
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 2) {
                    Text(monthDayLabel(day.date))
                        .font(.system(size: 15, weight: .bold))
                    Text(weekdayLabel(day.date))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 46)

                KFImage(URL(string: item.image_url))
                    .placeholder { Color.gray.opacity(0.12) }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 78, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !day.isExcluded else { return }
                        Haptic.impact(.soft)
                        choiceDate = PlannerSheetDate(value: day.date)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if !item.style.isEmpty {
                            Text(GenreDisplay.ja(item.style))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        if item.is_discovery {
                            discoveryBadge
                        }
                    }
                    if let weather = day.weather {
                        HStack(spacing: 4) {
                            WxWeatherIcon(condition: weather.condition, size: 12)
                            Text("\(DailyWeatherDisplay.compactCondition(weather.condition))・\(weather.min_temp)〜\(weather.max_temp)°C")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    // その日のひとこと (週ナラティブの day_line。旧サーバは理由文/なし)
                    if let line = day.dayLine ?? item.reason, !line.isEmpty {
                        Text(line)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .lineLimit(2)
                    }
                    if !item.owned_items.isEmpty {
                        HStack(spacing: 6) {
                            OwnedItemCircles(items: item.owned_items, size: 20, background: .white)
                            Text("手持ち\(item.owned_items.count)点")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if day.hasExistingPlan {
                        Text(day.isExcluded ? "予定あり（この日はそのまま）" : "予定あり（上書きします）")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(day.isExcluded ? Color.secondary : Color.red)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                pillButton(
                    "候補から選ぶ",
                    systemImage: "rectangle.on.rectangle",
                    disabled: day.isExcluded || day.candidates.count <= 1
                ) {
                    choiceDate = PlannerSheetDate(value: day.date)
                }
                pillButton(
                    day.isExcluded ? "戻す" : "除外",
                    systemImage: day.isExcluded ? "plus.circle" : "minus.circle",
                    disabled: false
                ) {
                    viewModel.toggleExclude(day.date)
                }
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .opacity(day.isExcluded ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.15), value: day.isExcluded)
    }

    // グリッド表示 (11日以上)。セルタップで候補シート
    private var planGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            // 先頭日の曜日に合わせてオフセット
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.aspectRatio(3/4, contentMode: .fill)
            }
            ForEach(viewModel.days) { day in
                Button {
                    Haptic.impact(.soft)
                    choiceDate = PlannerSheetDate(value: day.date)
                } label: {
                    ZStack {
                        KFImage(URL(string: day.selected.image_url))
                            .placeholder { Color.gray.opacity(0.12) }
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(3/4, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .opacity(day.isExcluded ? 0.3 : 1)

                        Text(dayNumberLabel(day.date))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(4)

                        if day.isExcluded {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                    }
                    .aspectRatio(3/4, contentMode: .fill)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var leadingBlanks: Int {
        guard let first = viewModel.days.first, let date = parseDate(first.date) else { return 0 }
        return Calendar.current.component(.weekday, from: date) - 1
    }

    // MARK: 栞 (保存後の完成儀式)

    private func bookmarkOverlay(savedCount count: Int) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            PlannerBookmarkCard(
                days: viewModel.days.filter { !$0.isExcluded },
                weekTitle: viewModel.weekTitle,
                savedCount: count,
                closing: PlannerVoice.closing(for: viewModel.speakingStyle),
                onFinish: { finishBookmark() }
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { finishBookmark() }
    }

    /// 栞を閉じてカレンダーへ戻る (タップと自動タイマーの両方から呼ばれるため1回だけ pop する)
    private func finishBookmark() {
        guard savedCount != nil else { return }
        savedCount = nil
        path.removeLast()
    }

    // MARK: 部品

    private func segment(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(text)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.black : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.clear : Color.black.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func customChip(_ label: String, days: Int) -> some View {
        let selected = viewModel.customDays == days
        return Button {
            Haptic.impact(.soft)
            viewModel.customDays = days
        } label: {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Color.black : Color.white)
                .overlay(
                    Capsule().stroke(selected ? Color.clear : Color.black.opacity(0.18), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func pillButton(_ label: String, systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white)
            .overlay(Capsule().stroke(Color.black.opacity(0.18), lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private func ctaBar(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptic.impact(.medium)
                action()
            } label: {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(enabled ? Color.black : Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!enabled)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.white)
    }

    // MARK: 日付ヘルパー

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }

    private func monthDayLabel(_ dateString: String) -> String {
        guard let date = parseDate(dateString) else { return dateString }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func weekdayLabel(_ dateString: String) -> String {
        guard let date = parseDate(dateString) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func dayNumberLabel(_ dateString: String) -> String {
        String(Int(dateString.suffix(2)) ?? 0)
    }
}

/// sheet(item:) 用の String ラッパー
private struct PlannerSheetDate: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - 候補シート (軸ラベル付きの選び直し + 除外)

private struct PlanChoiceSheet: View {
    let viewModel: OutfitPlannerViewModel
    let date: String
    let onClose: () -> Void

    /// シート表示中も最新の選択状態を反映する
    private var day: OutfitPlannerViewModel.PlanDayState? {
        viewModel.days.first { $0.date == date }
    }

    var body: some View {
        if let day {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(titleLabel(day))
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Button("閉じる", action: onClose)
                        .font(.system(size: 14))
                        .foregroundStyle(.black)
                }
                .padding(.top, 18)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        // 軸付き候補: 最初の提案 + 堅実/挑戦/気分転換 (行で比較して選ぶ)
                        choiceRow(day: day, index: 0, axis: nil)
                        ForEach(taggedIndices(day), id: \.self) { index in
                            choiceRow(day: day, index: index, axis: axis(day, index: index))
                        }

                        // そのほかの候補 (サムネイルgrid)
                        let others = untaggedIndices(day)
                        if !others.isEmpty {
                            Text("そのほかの候補")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(others, id: \.self) { index in
                                    choiceThumb(day: day, index: index)
                                }
                            }
                        }

                        // 除外トグル (グリッド表示のセルからも除外できるようにシート内に置く)
                        Button {
                            Haptic.impact(.soft)
                            viewModel.toggleExclude(day.date)
                        } label: {
                            Label(
                                day.isExcluded ? "この日を戻す" : "この日は不要",
                                systemImage: day.isExcluded ? "plus.circle" : "minus.circle"
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func titleLabel(_ day: OutfitPlannerViewModel.PlanDayState) -> String {
        let parts = day.date.split(separator: "-")
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) {
            return "\(m)月\(d)日のコーデをえらぶ"
        }
        return day.date
    }

    private func axis(_ day: OutfitPlannerViewModel.PlanDayState, index: Int) -> PlanAxis? {
        PlanAxis(rawValue: day.candidates[index].alt_tag ?? "")
    }

    /// 軸ラベルが付いた入替候補のインデックス (本命 index 0 は除く)
    private func taggedIndices(_ day: OutfitPlannerViewModel.PlanDayState) -> [Int] {
        day.candidates.indices.filter { $0 > 0 && axis(day, index: $0) != nil }
    }

    private func untaggedIndices(_ day: OutfitPlannerViewModel.PlanDayState) -> [Int] {
        day.candidates.indices.filter { $0 > 0 && axis(day, index: $0) == nil }
    }

    private func choiceRow(day: OutfitPlannerViewModel.PlanDayState, index: Int, axis: PlanAxis?) -> some View {
        let item = day.candidates[index].item
        let isSelected = index == day.selectedIndex
        return Button {
            viewModel.select(date: day.date, index: index)
        } label: {
            HStack(spacing: 12) {
                KFImage(URL(string: item.image_url))
                    .placeholder { Color.gray.opacity(0.12) }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 62, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    if let axis {
                        HStack(spacing: 3) {
                            Image(systemName: axis.icon)
                                .font(.system(size: 9, weight: .semibold))
                            Text(axis.label)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(axis.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(axis.tint.opacity(0.3), lineWidth: 0.9))
                        Text(axis.caption)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("最初の提案")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(item.style.isEmpty ? "" : GenreDisplay.ja(item.style))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                    Text(item.owned_items.isEmpty
                         ? "手持ち一致なし"
                         : "手持ち\(item.owned_items.count)点で作れる")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .black : Color.gray.opacity(0.35))
            }
            .padding(10)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.black.opacity(0.55) : Color.black.opacity(0.08),
                            lineWidth: isSelected ? 1.6 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func choiceThumb(day: OutfitPlannerViewModel.PlanDayState, index: Int) -> some View {
        let item = day.candidates[index].item
        let isSelected = index == day.selectedIndex
        return Button {
            viewModel.select(date: day.date, index: index)
        } label: {
            Color.gray.opacity(0.12)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    KFImage(URL(string: item.image_url))
                        .placeholder { Color.gray.opacity(0.12) }
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                            .background(Circle().fill(.white))
                            .padding(4)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 栞カード (保存後の完成儀式)

private struct PlannerBookmarkCard: View {
    let days: [OutfitPlannerViewModel.PlanDayState]
    let weekTitle: String?
    let savedCount: Int
    let closing: String
    let onFinish: () -> Void

    @State private var appearedCount = 0
    @State private var showCheck = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 52, height: 52)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(showCheck ? 1 : 0.2)
            .opacity(showCheck ? 1 : 0)

            Text(weekTitle ?? "\(savedCount)日分のコーデ")
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.center)

            // 7サムネイルが横1列に順に綴じられる (8日以上は先頭7日分)
            HStack(spacing: 4) {
                ForEach(Array(days.prefix(7).enumerated()), id: \.element.date) { index, day in
                    KFImage(URL(string: day.selected.image_url))
                        .placeholder { Color.gray.opacity(0.15) }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .opacity(index < appearedCount ? 1 : 0)
                        .offset(y: index < appearedCount ? 0 : 8)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("\(savedCount)日分をカレンダーに追加しました")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(closing)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 32)
        .task {
            for index in 0..<min(days.count, 7) {
                try? await Task.sleep(nanoseconds: 110_000_000)
                withAnimation(.easeOut(duration: 0.25)) {
                    appearedCount = index + 1
                }
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                showCheck = true
            }
            // 余韻ののちカレンダーへ (タップで即時戻れる)
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            onFinish()
        }
    }
}

#Preview {
    NavigationStack {
        OutfitPlannerView(path: .constant([]))
    }
}
