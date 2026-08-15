//
//  CalendarView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//
//  2026-08: WEAR/ZOZOTOWN 風に刷新。全月の縦積みスクロールをやめ、
//  月スイッチャー (‹ 8月 › + スワイプ) の1ヶ月ページャと、
//  3列写真グリッドの「一覧」表示の2モード構成にした。
//  データ層 (CalendarViewModel) は無改修 (全月ロード済みの months/monthStates に索引するだけ)。
//

import Foundation
import SwiftUI
import Kingfisher

struct CalendarView: View {
    @State var viewModel: CalendarViewModel
    @Binding var path: [ViewType]
    @Environment(MainTabViewModel.self) private var tabViewModel
    @Environment(\.dismiss) private var dismiss

    /// カレンダー (月ページャ) ⇄ 一覧 (3列写真グリッド)。選択は次回起動でも維持する
    private enum DisplayMode: String {
        case calendar
        case grid
    }
    @AppStorage("calendar.displayMode") private var displayModeRaw = DisplayMode.calendar.rawValue
    private var displayMode: DisplayMode { DisplayMode(rawValue: displayModeRaw) ?? .calendar }

    /// 表示中の月 (viewModel.months への索引。months は新しい順)。nil は今月で未初期化
    @State private var selectedMonthIndex: Int? = nil

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    // 予定コーデのタップ操作。ダイアログを挟まず詳細を直接開き、削除は詳細画面内で行う
    @State private var presentedPlannedPool: PresentedPlannedPool? = nil
    @State private var presentedSelfPlanned: CalendarOutfit? = nil
    @State private var isLoadingPlannedDetail = false
    /// 同日複数コーデの日別一覧シート
    @State private var daySheetData: CalendarDaySheetData? = nil
    /// 空き日タップからの「その日の提案」シート
    @State private var suggestionData: CalendarDaySuggestionData? = nil

    /// pool の予定コーデ詳細シートに渡す組 (削除に予定日が要るため item と一緒に保持する)
    private struct PresentedPlannedPool: Identifiable {
        let outfit: CalendarOutfit
        let item: DailyRecommendationItem
        var id: String { outfit.date }
    }

    #if DEBUG
    /// Sandbox 検証画面の入口 (週間プランナー / 同日複数コーデUI)。実uidのまま実APIを叩いて確認する
    @State private var showSandboxMenu = false
    #endif

    var body: some View {
        Group {
            if viewModel.months.isEmpty || viewModel.isInitiallyLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.allLoaded && !viewModel.hasAnyCoordinates {
                EmptyStateView(path: $path)
            } else {
                VStack(spacing: 0) {
                    headerBar
                    hairline
                    plannerEntryCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    switch displayMode {
                    case .calendar:
                        monthPager
                    case .grid:
                        recordsGrid
                    }
                }
            }
        }
        .background(.white)
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        // 「まとめて提案」の導線はヘッダー下の plannerEntryCard に一本化した
        #if DEBUG
        // Sandbox 検証画面の入口。Release ビルドには入らない
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptic.impact(.soft)
                    showSandboxMenu = true
                } label: {
                    Image(systemName: "flask")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
        }
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if DEBUG
        .sheet(isPresented: $showSandboxMenu) {
            NavigationStack {
                List {
                    NavigationLink("週間コーデプランナー") { WeeklyPlannerSandboxView() }
                    NavigationLink("同日複数コーデUI (Mock)") {
                        CalendarMultiCoordSandboxView(dataSource: .mock(delay: 0))
                    }
                    NavigationLink("同日複数コーデUI (実API)") {
                        CalendarMultiCoordSandboxView(dataSource: .real)
                    }
                }
                .navigationTitle("Sandbox")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("閉じる") { showSandboxMenu = false }
                    }
                }
            }
        }
        #endif
        .task {
            AnalyticsLogger.shared.log(screen: .memoryCalendarScreenView)
            await viewModel.onAppear()
        }
        .onDisappear {
            AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                "action": GAEventAction.backToCamera.rawValue
            ])
        }
        .onChange(of: path) { oldPath, newPath in
            if !oldPath.isEmpty && newPath.isEmpty {
                Task {
                    viewModel.hasLoaded = false
                    await viewModel.onAppear()
                }
            } else if oldPath.count > newPath.count {
                // まとめて提案などから戻ってきたら予定コーデを再取得して反映する
                Task { await viewModel.loadPlanned() }
            }
        }
        // pool の予定コーデ詳細。削除は詳細画面内の「予定から削除」で行う。
        // シート閉鎖では onChange(path) が発火しないため、削除は必ず viewModel.deletePlanned を
        // 経由してローカルの plannedByDate を即時更新する
        .sheet(item: $presentedPlannedPool) { presented in
            NavigationStack {
                DailyRecommendationDetailView(
                    item: presented.item,
                    onWear: { it in await viewModel.markWornToday(it) },
                    plannedDate: presented.outfit.date,
                    onDeletePlanned: {
                        let ok = await viewModel.deletePlanned(presented.outfit)
                        if ok {
                            ToastManager.shared.show("予定を削除しました", style: .normal)
                        }
                        return ok
                    },
                    isAdopted: presented.outfit.isAdopted,
                    onAdopt: { await viewModel.adoptPlanned(presented.outfit) },
                    onUnadopt: { await viewModel.unadoptPlanned(presented.outfit) },
                    onShowCandidates: canReplaceCandidates(date: presented.outfit.date) ? {
                        presentedPlannedPool = nil
                        openReplaceCandidates(date: presented.outfit.date)
                    } : nil
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") { presentedPlannedPool = nil }
                    }
                }
            }
        }
        // self (自分のコーデ) の予定コーデ詳細。pool と同じくシートで直接開き、
        // 削除はツールバーのメニューから行う (画面本体は既存の CoordinateDetailView を無改修で流用)
        .sheet(item: $presentedSelfPlanned) { planned in
            NavigationStack {
                CoordinateDetailView(
                    viewModel: .init(
                        coordinateId: planned.target_id,
                        coordinateImageURL: planned.image_url,
                        coordinateDetailClient: CoordinateDetailClient()
                    ),
                    showHeader: false
                )
                .navigationTitle(plannedTitle(planned))
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("閉じる") { presentedSelfPlanned = nil }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            // 採用 = 提案(予定)のままでも削除でもない第3の状態「その日のコーデ」
                            if planned.isAdopted {
                                Button("採用を取り消す") {
                                    Task {
                                        if await viewModel.unadoptPlanned(planned) {
                                            presentedSelfPlanned = viewModel.plannedByDate[planned.date]
                                        }
                                    }
                                }
                            } else {
                                Button("この日のコーデにする") {
                                    Task {
                                        if await viewModel.adoptPlanned(planned) {
                                            ToastManager.shared.show("この日のコーデに採用しました", style: .normal)
                                            presentedSelfPlanned = viewModel.plannedByDate[planned.date]
                                        }
                                    }
                                }
                            }
                            if canReplaceCandidates(date: planned.date) {
                                Button("別の候補から選び直す") {
                                    presentedSelfPlanned = nil
                                    openReplaceCandidates(date: planned.date)
                                }
                            }
                            Button("予定から削除", role: .destructive) {
                                Task {
                                    if await viewModel.deletePlanned(planned) {
                                        ToastManager.shared.show("予定を削除しました", style: .normal)
                                        presentedSelfPlanned = nil
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
        }
        // 同日複数コーデの切り替えシート。選択後はシートが閉じてから既存の詳細導線へ渡す
        // (シートの閉鎖アニメーションと次のシート/pushが競合しないよう少し遅らせる)
        .sheet(item: $daySheetData) { data in
            CalendarDayOutfitsSheet(
                data: data,
                onSelectRecord: { record in
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        openRecord(record)
                    }
                },
                onSelectOutfit: { outfit in
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        await openPlannedDetail(outfit)
                    }
                },
                onShowCandidates: canReplaceCandidates(date: data.date)
                    ? { openReplaceCandidates(date: data.date, dateLabel: data.dateLabel) }
                    : nil
            )
        }
        // 空き日タップからの「その日の提案」シート (提案体験の入口)
        .sheet(item: $suggestionData) { data in
            CalendarDaySuggestionSheet(
                data: data,
                load: { await viewModel.suggest(forDate: data.date) },
                onPlan: { item in await viewModel.savePlanned(date: data.date, item: item) },
                onOpenPlanner: {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        path.append(.outfitPlanner)
                    }
                }
            )
        }
        .overlay {
            if isLoadingPlannedDetail {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
        }
    }

    // MARK: - プランナー導線 (まとめて提案)

    /// 予定コーデの残弾で文言が変わる常設の導線カード。
    /// 残り2日以下で「仕込む?」と促す (残弾駆動 — 固定曜日の儀式にせずユーザーのペースに追従)
    private var plannerEntryCard: some View {
        let upcoming = viewModel.upcomingPlannedCount
        let (title, subtitle): (String, String) = {
            if upcoming == 0 {
                return ("相棒にコーデプランを考えてもらう",
                        "天気と手持ちに合わせて、1週間分まで先取り提案します")
            }
            if upcoming <= 2 {
                return ("予定コーデが残り\(upcoming)日分",
                        "次の1週間ぶんを仕込みませんか？")
            }
            return ("予定コーデを\(upcoming)日分ストック中",
                    "タップで追加の提案が作れます")
        }()

        return Button {
            Haptic.impact(.soft)
            path.append(.outfitPlanner)
        } label: {
            HStack(spacing: 12) {
                // 「相棒が考える」ことが伝わるよう、機能アイコンではなく相棒の顔を出す
                PartnerIconImage(size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.gray.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - ヘッダー (月スイッチャー + 今日 + 表示切替)

    /// 今月の索引 (months は新しい順で来月が先頭のことが多い)
    private var currentMonthIndex: Int {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        return viewModel.months.firstIndex {
            $0.year == comps.year && $0.monthOfTheYear == comps.month
        } ?? 0
    }

    private var monthIndex: Int {
        min(selectedMonthIndex ?? currentMonthIndex, max(viewModel.months.count - 1, 0))
    }

    private var selectedMonth: Month? {
        viewModel.months.indices.contains(monthIndex) ? viewModel.months[monthIndex] : nil
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            if displayMode == .calendar {
                monthSwitcher
                if monthIndex != currentMonthIndex {
                    todayPill
                }
            } else {
                Text("すべての記録")
                    .font(.system(size: 16, weight: .bold))
                Text("\(allRecordEntries.count)件")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            modeToggle
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.white)
    }

    private var monthSwitcher: some View {
        HStack(spacing: 2) {
            // months は新しい順のため、過去へ = index+1 / 未来へ = index-1
            // (ハプティクスは monthPager の onChange で一元化)
            Button {
                goToPastMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoPast ? .black : Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoPast)

            // Text("") が LocalizedStringKey に解決されると年が「2,026」と桁区切りされるため verbatim 指定
            Text(verbatim: selectedMonth.map { "\($0.year)年\($0.monthOfTheYear)月" } ?? "")
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .frame(minWidth: 108)

            Button {
                goToFutureMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoFuture ? .black : Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoFuture)
        }
    }

    private var todayPill: some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) {
                selectedMonthIndex = currentMonthIndex
            }
        } label: {
            Text("今日")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(Color.gray.opacity(0.35), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// カレンダー ⇄ 一覧 (WEAR の表示切替と同じ2アイコンのセグメント)
    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeToggleButton(.calendar, icon: "calendar")
            modeToggleButton(.grid, icon: "square.grid.3x3")
        }
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func modeToggleButton(_ mode: DisplayMode, icon: String) -> some View {
        let isSelected = displayMode == mode
        return Button {
            Haptic.selection()
            withAnimation(.easeOut(duration: 0.2)) {
                displayModeRaw = mode.rawValue
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color.black.opacity(0.55))
                .frame(width: 40, height: 30)
                .background(isSelected ? Color.black : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(height: 0.5)
    }

    // MARK: - 月ページャ (カレンダー表示)

    private var canGoPast: Bool { monthIndex < viewModel.months.count - 1 }
    private var canGoFuture: Bool { monthIndex > 0 }

    private func goToPastMonth() {
        guard canGoPast else { return }
        withAnimation(.easeOut(duration: 0.25)) { selectedMonthIndex = monthIndex + 1 }
    }

    private func goToFutureMonth() {
        guard canGoFuture else { return }
        withAnimation(.easeOut(duration: 0.25)) { selectedMonthIndex = monthIndex - 1 }
    }

    /// 横スクロールのページング。指に追従して隣の月へ連続的にスライドする
    /// (以前は .id 差し替え + onEnded スワイプ判定だったため切替が非連続だった)。
    /// チェブロン/今日ボタンからの withAnimation による selectedMonthIndex 変更も
    /// scrollPosition 経由で同じスライドアニメーションになる。
    private var monthPager: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    // months は新しい順のため、左=過去 / 右=未来 になるよう逆順に並べる
                    ForEach(Array(viewModel.months.indices.reversed()), id: \.self) { index in
                        monthPage(index: index)
                            .frame(width: geo.size.width)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: pagerPosition)
        }
        // 月の切替ハプティクスはここで一元化 (スワイプ/チェブロン/今日ボタンすべて発火)
        .onChange(of: monthIndex) { _, _ in
            Haptic.selection()
        }
    }

    /// scrollPosition との橋渡し。get が nil を今月に解決するため、
    /// 初回表示時から今月のページに (アニメーションなしで) 位置合わせされる
    private var pagerPosition: Binding<Int?> {
        Binding(
            get: { monthIndex },
            set: { selectedMonthIndex = $0 }
        )
    }

    /// 1ヶ月ぶんのページ。1画面に必ず収まるレイアウト (縦スクロールなし)。
    /// グリッドは残り高さを GeometryReader で受け、セル高を行数から逆算する。
    @ViewBuilder
    private func monthPage(index: Int) -> some View {
        let month = viewModel.months[index]
        let state = monthState(at: index)
        VStack(alignment: .leading, spacing: 10) {
            statsRow(for: month, state: state)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            switch state {
            case .loading:
                weekdayHeader
                    .padding(.horizontal, 16)
                monthSkeletonGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            case .loaded(let responses):
                if !hasAnyEntry(month: month, responses: responses) {
                    emptyMonthHint
                        .padding(.horizontal, 16)
                }
                weekdayHeader
                    .padding(.horizontal, 16)
                gridArea(month: month, responses: responses)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            case .failed:
                // 失敗時も日付グリッドは描画し、予定コーデだけでも見せる (従来挙動の踏襲)
                if !viewModel.hasPlanned(year: month.year, month: month.monthOfTheYear) {
                    emptyMonthHint
                        .padding(.horizontal, 16)
                }
                weekdayHeader
                    .padding(.horizontal, 16)
                gridArea(month: month, responses: [])
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func monthState(at index: Int) -> MonthLoadState {
        viewModel.monthStates.indices.contains(index)
            ? viewModel.monthStates[index] : .loading
    }

    private func hasAnyEntry(month: Month, responses: [CoordinateListResponse]) -> Bool {
        responses.contains { $0.coodinate_image_path != nil }
            || viewModel.hasPlanned(year: month.year, month: month.monthOfTheYear)
    }

    /// 記録◯件・予定◯件 (WEAR 風の控えめなキャプション)
    private func statsRow(for month: Month, state: MonthLoadState) -> some View {
        let recordCount: Int = {
            if case .loaded(let responses) = state {
                return responses.filter { $0.displayImageURL != nil }.count
            }
            return 0
        }()
        let plannedPrefix = String(format: "%04d-%02d-", month.year, month.monthOfTheYear)
        let monthOutfits = viewModel.plannedByDate.filter { $0.key.hasPrefix(plannedPrefix) }
        let plannedCount = monthOutfits.filter { !$0.value.isAdopted }.count
        let adoptedCount = monthOutfits.filter { $0.value.isAdopted }.count
        return HStack(spacing: 10) {
            Label("記録 \(recordCount)件", systemImage: "camera.fill")
            if adoptedCount > 0 {
                Label("採用 \(adoptedCount)件", systemImage: "checkmark.circle")
            }
            if plannedCount > 0 {
                Label("予定 \(plannedCount)件", systemImage: "clock")
            }
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 5) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { i, wd in
                Text(wd)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(weekdayColor(i))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// 月を週単位の行 ([Int?] の7要素、nil = 月外の空セル) に分割する
    private func weeks(for month: Month) -> [[Int?]] {
        let leadingBlanks = max(month.spacesBeforeFirst - 1, 0)
        var cells: [Int?] = Array(repeating: nil, count: leadingBlanks)
        cells.append(contentsOf: (1...month.amountOfDays).map { Optional($0) })
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    /// 週を横1行 (7日) とし、行高 = 残り高さ ÷ 週数 で均等分割する。
    /// 月全体が必ず1画面に収まり、画面をちょうど使い切るカレンダー形式。
    private func gridArea(month: Month, responses: [CoordinateListResponse]) -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = 5
            let weekRows = weeks(for: month)
            let rowHeight = max(
                30,
                (geo.size.height - spacing * CGFloat(weekRows.count - 1)) / CGFloat(weekRows.count)
            )

            VStack(spacing: spacing) {
                ForEach(Array(weekRows.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: spacing) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                dayCell(month: month, day: day, responses: responses, cellHeight: rowHeight)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(height: rowHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 日=赤 / 土=青 (日本のカレンダー慣習)。それ以外はグレー
    private func weekdayColor(_ index: Int) -> Color {
        switch index {
        case 0: return Color.red.opacity(0.65)
        case 6: return Color.blue.opacity(0.65)
        default: return Color.gray.opacity(0.55)
        }
    }

    private var emptyMonthHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.gray.opacity(0.35))
            Text("この月の記録はありません")
                .font(.system(size: 13))
                .foregroundStyle(Color.gray.opacity(0.45))
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            Color.gray.opacity(0.15),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                )
        )
    }

    // MARK: - 月スケルトン (ロード中)

    private var monthSkeletonGrid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 5
            let rows = 6
            let rowHeight = max(30, (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { _ in
                    HStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.09))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: rowHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Day Cell

    private func dayCell(month: Month, day: Int, responses: [CoordinateListResponse], cellHeight: CGFloat) -> some View {
        // include_all=1 のため同日複数行があり得る。day で突合し画像のある行だけ拾う (サーバ順 = created_at 順)
        let dayRecords = responses.filter { $0.day == day && $0.displayImageURL != nil }
        // 予定/採用コーデは記録と同居させる (以前は「記録がある日は予定が不可視」だった)
        let planned = viewModel.planned(year: month.year, month: month.monthOfTheYear, day: day)
        let totalCount = dayRecords.count + (planned == nil ? 0 : 1)
        let isToday = checkIsToday(year: month.year, month: month.monthOfTheYear, day: day)
        let dateString = String(format: "%04d-%02d-%02d", month.year, month.monthOfTheYear, day)
        // 空いている今日以降の日は「その日の提案」を体験できる
        let canSuggest = totalCount == 0 && dateString >= HomeViewModel.jstTodayString()

        return Button(action: {
            handleDayTap(month: month, day: day, dateString: dateString, dayRecords: dayRecords, planned: planned)
        }) {
            ZStack {
                if let record = dayRecords.first, let imageURL = record.displayImageURL {
                    coordinateImage(from: imageURL)
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: cellHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    dayNumberOverlay(day)
                } else if let planned {
                    coordinateImage(from: planned.image_url)
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: cellHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            // 破線 = 「まだ着ていない予定」。採用済みは実線 (記録と同格) に昇格
                            if !planned.isAdopted {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        Color.black.opacity(0.4),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                    )
                            }
                        }
                    dayNumberOverlay(day)
                    if planned.isAdopted {
                        AdoptedCheckBadge(size: 14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(3)
                    } else {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(4)
                    }
                } else {
                    Color.clear

                    VStack(spacing: 4) {
                        if isToday {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 28, height: 28)
                                Text("\(day)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        } else {
                            Text("\(day)")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }
                        // 破線サークル+plus = 「未定の日は提案してもらえる」入口 (認知獲得の常設アフォーダンス)
                        if canSuggest && cellHeight >= 48 {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        Color.gray.opacity(0.45),
                                        style: StrokeStyle(lineWidth: 1, dash: [2.5, 2])
                                    )
                                Image(systemName: "plus")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(Color.gray.opacity(0.6))
                            }
                            .frame(width: 16, height: 16)
                        }
                    }
                }

                // 同日複数 (記録N件 + 予定/採用) のインジケータ。タップで日別シートへ
                if totalCount > 1 {
                    HStack(spacing: 2) {
                        Image(systemName: "square.on.square.fill")
                            .font(.system(size: 7, weight: .bold))
                        if cellHeight >= 40 {
                            Text(totalCount > 9 ? "9+" : "\(totalCount)")
                                .font(.system(size: 9, weight: .bold))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(3)
                }
            }
            .frame(height: cellHeight)
            // 今日の強調: 画像やコーデのある日でも今日が分かる黒リング
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.black, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(totalCount == 0 && !canSuggest)
    }

    private func dayNumberOverlay(_ day: Int) -> some View {
        Text("\(day)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(4)
    }

    private func handleDayTap(
        month: Month,
        day: Int,
        dateString: String,
        dayRecords: [CoordinateListResponse],
        planned: CalendarOutfit?
    ) {
        let totalCount = dayRecords.count + (planned == nil ? 0 : 1)
        let dateLabel = "\(month.monthOfTheYear)月\(day)日"
        if totalCount > 1 {
            // 複数の日だけ日別シートを挟む (1件の日は従来通り即遷移)
            Haptic.selection()
            daySheetData = CalendarDaySheetData(date: dateString, dateLabel: dateLabel, records: dayRecords, outfit: planned)
        } else if let record = dayRecords.first {
            openRecord(record)
        } else if let planned {
            Haptic.impact(.soft)
            Task { await openPlannedDetail(planned) }
        } else {
            Haptic.impact(.soft)
            suggestionData = CalendarDaySuggestionData(date: dateString, dateLabel: dateLabel)
        }
    }

    /// 着用記録の詳細へ (単日直タップ / 日別シート選択の共通ルート)
    private func openRecord(_ record: CoordinateListResponse) {
        guard let imageURL = record.displayImageURL,
              let coordinateId = record.id, !coordinateId.isEmpty else { return }
        let targetDateString = String(format: "%04d-%02d-%02d", record.year, record.month, record.day)
        AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
            "date": targetDateString,
            "has_coordinate": true
        ])
        path.append(.coordinateDetail(.init(
            coordinateId: coordinateId,
            coordinateImageURL: imageURL,
            showHeader: false
        )))
    }

    // MARK: - 一覧 (3列写真グリッド。WEAR のフィードと同じ極小ギャップ)

    private struct RecordEntry: Identifiable {
        /// 一覧に載せる対象は「提案 (未採用の予定) 以外」= 着用記録 + 採用コーデ
        enum Source {
            case record(coordinateId: String)
            case adopted(CalendarOutfit)
        }

        let id: String
        let year: Int
        let month: Int
        let day: Int
        let imageURL: String
        let source: Source

        var dateKey: String { String(format: "%04d-%02d-%02d", year, month, day) }
        var isAdopted: Bool {
            if case .adopted = source { return true }
            return false
        }
    }

    /// 全ロード済み月の記録 (同日複数含む) + 採用コーデを新しい順に平坦化する。
    /// 未採用の予定 (提案されているだけのコーデ) は一覧に載せない
    private var allRecordEntries: [RecordEntry] {
        var keyed: [(key: String, order: Int, entry: RecordEntry)] = []
        for (i, month) in viewModel.months.enumerated() {
            guard viewModel.monthStates.indices.contains(i),
                  case .loaded(let responses) = viewModel.monthStates[i] else { continue }
            for (index, resp) in responses.enumerated() {
                guard let imageURL = resp.displayImageURL,
                      let coordinateId = resp.id, !coordinateId.isEmpty else { continue }
                let entry = RecordEntry(
                    id: "\(month.year)-\(month.monthOfTheYear)-\(resp.day)-\(coordinateId)",
                    year: month.year,
                    month: month.monthOfTheYear,
                    day: resp.day,
                    imageURL: imageURL,
                    source: .record(coordinateId: coordinateId)
                )
                keyed.append((entry.dateKey, index, entry))
            }
        }
        for outfit in viewModel.plannedByDate.values where outfit.isAdopted {
            let parts = outfit.date.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { continue }
            let entry = RecordEntry(
                id: "adopted-\(outfit.date)",
                year: y, month: m, day: d,
                imageURL: outfit.image_url,
                source: .adopted(outfit)
            )
            // 同日では撮影記録の後ろに並べる
            keyed.append((entry.dateKey, Int.max, entry))
        }
        return keyed
            .sorted { $0.key == $1.key ? $0.order < $1.order : $0.key > $1.key }
            .map(\.entry)
    }

    private var recordsGrid: some View {
        ScrollView(showsIndicators: false) {
            if allRecordEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    Text("まだ記録がありません")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(allRecordEntries) { entry in
                        recordTile(entry)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
    }

    private func recordTile(_ entry: RecordEntry) -> some View {
        Button {
            switch entry.source {
            case .record(let coordinateId):
                AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                    "date": entry.dateKey,
                    "has_coordinate": true
                ])
                path.append(.coordinateDetail(.init(
                    coordinateId: coordinateId,
                    coordinateImageURL: entry.imageURL,
                    showHeader: false
                )))
            case .adopted(let outfit):
                Haptic.impact(.soft)
                Task { await openPlannedDetail(outfit) }
            }
        } label: {
            coordinateImage(from: entry.imageURL)
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity,
                       minHeight: 0, maxHeight: .infinity)
                .aspectRatio(3/4, contentMode: .fill)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    Text("\(entry.month)/\(entry.day)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 2)
                        .padding(6)
                }
                .overlay(alignment: .bottomTrailing) {
                    // 採用コーデの視覚言語 (セル/日別シートと共通の ✓)
                    if entry.isAdopted {
                        AdoptedCheckBadge()
                            .padding(6)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func plannedTitle(_ planned: CalendarOutfit) -> String {
        let parts = planned.date.split(separator: "-")
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) {
            return "\(m)月\(d)日の予定コーデ"
        }
        return "予定コーデ"
    }

    /// "2026-08-20" → "8月20日" (パース不能ならそのまま)
    private func dayLabel(fromDateString date: String) -> String {
        let parts = date.split(separator: "-")
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) {
            return "\(m)月\(d)日"
        }
        return date
    }

    /// 予定の選び直し (候補一覧) を出せるか。plan API の対象になる今日以降のみ
    private func canReplaceCandidates(date: String) -> Bool {
        date >= HomeViewModel.jstTodayString()
    }

    /// 予定ありの日の「別の候補から選び直す」。
    /// 表示中のシート (詳細 / 日別一覧) が閉じてから候補一覧を差し替えモードで開く
    private func openReplaceCandidates(date: String, dateLabel: String? = nil) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            suggestionData = CalendarDaySuggestionData(
                date: date,
                dateLabel: dateLabel ?? dayLabel(fromDateString: date),
                replacing: true
            )
        }
    }

    /// 予定コーデのセルタップで詳細を直接開く (以前の 詳細/削除 ダイアログは廃止し、削除は詳細画面内に移した)
    private func openPlannedDetail(_ planned: CalendarOutfit) async {
        if planned.kind == "self" {
            presentedSelfPlanned = planned
            return
        }
        isLoadingPlannedDetail = true
        let item = await viewModel.fetchPoolItem(planned)
        isLoadingPlannedDetail = false
        presentedPlannedPool = PresentedPlannedPool(outfit: planned, item: item)
    }

    @ViewBuilder
    private func coordinateImage(from path: String) -> some View {
        if path.hasPrefix("http"), let url = URL(string: path) {
            KFImage(url)
                .resizable()
        } else {
            Image(path)
                .resizable()
        }
    }

    private func checkIsToday(year: Int, month: Int, day: Int) -> Bool {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        return today.year == year && today.month == month && today.day == day
    }

    // MARK: - Empty State（全コーデ0件）

    private func EmptyStateView(path: Binding<[ViewType]>) -> some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray.opacity(0.5))
                VStack(spacing: 8) {
                    Text("コーデが登録されていません")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                    Text("コーデを登録すると、\nカレンダーで振り返ることができます")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            Button(action: {
                tabViewModel.shouldShowFirstTakePhotoOnHome = true
                tabViewModel.selectedTab = .home
                dismiss()
            }) {
                Text("コーデを登録する")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        CalendarView(viewModel: .init(apiClient: MockCoordinateListClient()), path: .constant([]))
            .environment(MainTabViewModel())
    }
}
