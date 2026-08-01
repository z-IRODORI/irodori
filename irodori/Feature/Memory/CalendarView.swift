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

    // 予定コーデのタップ操作 (詳細/削除の選択と pool 詳細シート)
    @State private var selectedPlanned: CalendarOutfit? = nil
    @State private var showPlannedDialog = false
    @State private var presentedPoolItem: DailyRecommendationItem? = nil
    @State private var isLoadingPlannedDetail = false

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptic.impact(.soft)
                    path.append(.outfitPlanner)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12, weight: .semibold))
                        Text("まとめて提案")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .confirmationDialog(
            plannedDialogTitle,
            isPresented: $showPlannedDialog,
            titleVisibility: .visible,
            presenting: selectedPlanned
        ) { planned in
            Button("詳細を見る") {
                Task { await openPlannedDetail(planned) }
            }
            Button("予定から削除", role: .destructive) {
                Task {
                    if await viewModel.deletePlanned(planned) {
                        ToastManager.shared.show("予定を削除しました", style: .normal)
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(item: $presentedPoolItem) { item in
            NavigationStack {
                DailyRecommendationDetailView(
                    item: item,
                    onWear: { it in await viewModel.markWornToday(it) }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") { presentedPoolItem = nil }
                    }
                }
            }
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
            Button {
                Haptic.selection()
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

            Text(selectedMonth.map { "\($0.year)年\($0.monthOfTheYear)月" } ?? "")
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .frame(minWidth: 108)

            Button {
                Haptic.selection()
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
            Haptic.selection()
            withAnimation(.easeOut(duration: 0.2)) {
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
        withAnimation(.easeOut(duration: 0.2)) { selectedMonthIndex = monthIndex + 1 }
    }

    private func goToFutureMonth() {
        guard canGoFuture else { return }
        withAnimation(.easeOut(duration: 0.2)) { selectedMonthIndex = monthIndex - 1 }
    }

    /// 1ヶ月が必ず1画面に収まるレイアウト (スクロールなし)。
    /// グリッドは残り高さを GeometryReader で受け、セル高を行数から逆算する。
    private var monthPager: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let month = selectedMonth {
                statsRow(for: month)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                switch monthState {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        // 左右スワイプでも月を移動できるようにする
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 50 else { return }
                    Haptic.selection()
                    if value.translation.width < 0 {
                        goToFutureMonth()
                    } else {
                        goToPastMonth()
                    }
                }
        )
        .id(monthIndex)
        .transition(.opacity)
    }

    private var monthState: MonthLoadState {
        viewModel.monthStates.indices.contains(monthIndex)
            ? viewModel.monthStates[monthIndex] : .loading
    }

    private func hasAnyEntry(month: Month, responses: [CoordinateListResponse]) -> Bool {
        responses.contains { $0.coodinate_image_path != nil }
            || viewModel.hasPlanned(year: month.year, month: month.monthOfTheYear)
    }

    /// 記録◯件・予定◯件 (WEAR 風の控えめなキャプション)
    private func statsRow(for month: Month) -> some View {
        let recordCount: Int = {
            if case .loaded(let responses) = monthState {
                return responses.filter { $0.displayImageURL != nil }.count
            }
            return 0
        }()
        let plannedPrefix = String(format: "%04d-%02d-", month.year, month.monthOfTheYear)
        let plannedCount = viewModel.plannedByDate.keys.filter { $0.hasPrefix(plannedPrefix) }.count
        return HStack(spacing: 10) {
            Label("記録 \(recordCount)件", systemImage: "camera.fill")
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
        // day フィールドで突合する (旧実装の配列インデックス依存は歯抜けデータでズレるため)
        let coord = responses.first { $0.day == day }
        // display_type に応じて撮影/切り取り画像を選ぶ
        let imageURL = coord?.displayImageURL
        let coordinateId = coord?.id
        // 着用記録がある日は記録を優先し、無い日だけ予定コーデを表示する
        let planned = imageURL == nil
            ? viewModel.planned(year: month.year, month: month.monthOfTheYear, day: day)
            : nil
        let isToday = checkIsToday(year: month.year, month: month.monthOfTheYear, day: day)

        return Button(action: {
            if let imageURL, let coordinateId, !coordinateId.isEmpty {
                let targetDateString = String(format: "%04d-%02d-%02d", month.year, month.monthOfTheYear, day)
                AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                    "date": targetDateString,
                    "has_coordinate": true
                ])
                let params = ViewType.CoordinateDetailParams(
                    coordinateId: coordinateId,
                    coordinateImageURL: imageURL,
                    showHeader: false
                )
                path.append(.coordinateDetail(params))
            } else if let planned {
                Haptic.impact(.soft)
                selectedPlanned = planned
                showPlannedDialog = true
            }
        }) {
            ZStack {
                if let imageURL {
                    coordinateImage(from: imageURL)
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: cellHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("\(day)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                } else if let planned {
                    // 予定コーデ: 破線枠 + 時計アイコンで「まだ着ていない予定」を表現
                    coordinateImage(from: planned.image_url)
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: cellHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    Color.black.opacity(0.4),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                )
                        )

                    Text("\(day)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(4)
                } else {
                    Color.clear

                    if isToday {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 28, height: 28)
                        Text("\(day)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(day)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                }
            }
            .frame(height: cellHeight)
        }
        .buttonStyle(.plain)
        .disabled(imageURL == nil && planned == nil)
    }

    // MARK: - 一覧 (3列写真グリッド。WEAR のフィードと同じ極小ギャップ)

    private struct RecordEntry: Identifiable {
        let id: String
        let year: Int
        let month: Int
        let day: Int
        let coordinateId: String
        let imageURL: String
    }

    /// 全ロード済み月の記録を新しい順に平坦化する (months が新しい順・月内は日の降順)
    private var allRecordEntries: [RecordEntry] {
        var entries: [RecordEntry] = []
        for (i, month) in viewModel.months.enumerated() {
            guard viewModel.monthStates.indices.contains(i),
                  case .loaded(let responses) = viewModel.monthStates[i] else { continue }
            let monthEntries = responses
                .compactMap { resp -> RecordEntry? in
                    guard let imageURL = resp.displayImageURL,
                          let coordinateId = resp.id, !coordinateId.isEmpty else { return nil }
                    return RecordEntry(
                        id: "\(month.year)-\(month.monthOfTheYear)-\(resp.day)-\(coordinateId)",
                        year: month.year,
                        month: month.monthOfTheYear,
                        day: resp.day,
                        coordinateId: coordinateId,
                        imageURL: imageURL
                    )
                }
                .sorted { $0.day > $1.day }
            entries.append(contentsOf: monthEntries)
        }
        return entries
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
            AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                "date": String(format: "%04d-%02d-%02d", entry.year, entry.month, entry.day),
                "has_coordinate": true
            ])
            path.append(.coordinateDetail(.init(
                coordinateId: entry.coordinateId,
                coordinateImageURL: entry.imageURL,
                showHeader: false
            )))
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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var plannedDialogTitle: String {
        guard let planned = selectedPlanned else { return "予定コーデ" }
        let parts = planned.date.split(separator: "-")
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) {
            return "\(m)月\(d)日の予定コーデ"
        }
        return "予定コーデ"
    }

    private func openPlannedDetail(_ planned: CalendarOutfit) async {
        if planned.kind == "self" {
            path.append(.coordinateDetail(.init(
                coordinateId: planned.target_id,
                coordinateImageURL: planned.image_url,
                showHeader: false
            )))
            return
        }
        isLoadingPlannedDetail = true
        let item = await viewModel.fetchPoolItem(planned)
        isLoadingPlannedDetail = false
        presentedPoolItem = item
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
