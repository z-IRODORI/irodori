//
//  CalendarMultiCoordSandbox.swift
//  irodori - Sandbox
//
//  同日に複数のコーデ (着用記録) が登録されている場合のカレンダーUI/UX検証。
//  セル表現 (バッジ/数字のみ/ずらし重ね) × 選択UI (シート/ダイアログ/ページャ) を
//  Picker で切り替えて比較する。確認後に CalendarView へ本番実装する。
//
//  データ前提: 現行 API (/api/coordinate/list) は同日複数件を1件に潰して返すため、
//  実API モードでは複数日は現れない (API に include_all=1 を足した後に複数行が届く想定)。
//  グルーピング (day -> [コーデ]) は本番でもこのファイルと同じ Dictionary(grouping:) で行う。
//
//  Mock の複数日: 8/4=2件, 8/12=3件, 8/18=5件, 8/21=記録2件+予定, 8/26=予定のみ
//

import SwiftUI
import Kingfisher

// MARK: - Mock データ

/// 1件の着用記録 (本番では CoordinateListResponse の同日グループ1要素に対応)
struct SandboxCoordEntry: Identifiable, Hashable {
    let id: String
    /// バンドル画像名 or httpのURL文字列
    let imagePath: String
    /// 登録時刻 (選択UIでの識別用。本番では created_at 由来)
    let registeredAt: String
}

/// 1日ぶんのデータ (記録0件以上 + 予定コーデの有無)
struct SandboxDayData: Identifiable {
    let day: Int
    let records: [SandboxCoordEntry]
    let hasPlanned: Bool
    var id: Int { day }
}

enum SandboxMultiCoordFixture {
    static let year = 2026
    static let month = 8

    /// 決定論的な Mock。複数件の日・記録+予定の日・予定のみの日を含む
    static func mockDays() -> [SandboxDayData] {
        func entry(_ day: Int, _ index: Int, _ image: Int, _ time: String) -> SandboxCoordEntry {
            SandboxCoordEntry(id: "mock-\(day)-\(index)", imagePath: "coordinate-\(image)", registeredAt: time)
        }
        var days: [SandboxDayData] = []
        let singles: [Int: (Int, String)] = [
            1: (1, "08:12"), 3: (2, "09:30"), 7: (3, "12:45"), 10: (4, "07:58"),
            15: (5, "10:21"), 24: (6, "18:03"), 28: (7, "08:44")
        ]
        for day in 1...31 {
            if let (image, time) = singles[day] {
                days.append(.init(day: day, records: [entry(day, 0, image, time)], hasPlanned: false))
            } else if day == 4 {
                days.append(.init(day: day, records: [entry(day, 0, 8, "07:40"), entry(day, 1, 9, "17:15")], hasPlanned: false))
            } else if day == 12 {
                days.append(.init(day: day, records: [entry(day, 0, 10, "08:05"), entry(day, 1, 1, "12:30"), entry(day, 2, 2, "19:02")], hasPlanned: false))
            } else if day == 18 {
                days.append(.init(day: day, records: (0..<5).map { entry(day, $0, $0 + 3, "0\($0 + 8):1\($0)") }, hasPlanned: false))
            } else if day == 21 {
                days.append(.init(day: day, records: [entry(day, 0, 8, "08:20"), entry(day, 1, 9, "13:40")], hasPlanned: true))
            } else if day == 26 {
                days.append(.init(day: day, records: [], hasPlanned: true))
            } else {
                days.append(.init(day: day, records: [], hasPlanned: false))
            }
        }
        return days
    }

    /// 予定コーデのダミー画像 (破線枠で表示する)
    static let plannedImagePath = "coordinate-10"
}

// MARK: - 本体

struct CalendarMultiCoordSandboxView: View {
    enum DataSource {
        case mock(delay: TimeInterval)
        case real
    }

    enum CellVariant: String, CaseIterable, Identifiable {
        case badge = "A: ⧉+数"
        case count = "B: 数字のみ"
        case stack = "C: 重ね"
        var id: String { rawValue }
    }

    enum SelectVariant: String, CaseIterable, Identifiable {
        case sheet = "シート"
        case dialog = "ダイアログ"
        case pager = "ページャ"
        var id: String { rawValue }
    }

    var dataSource: DataSource = .mock(delay: 0)

    @State private var cellVariant: CellVariant = .badge
    @State private var selectVariant: SelectVariant = .sheet
    @State private var cellHeight: CGFloat = 64

    @State private var days: [SandboxDayData]? = nil

    // 選択UIの提示状態
    @State private var sheetDay: SandboxDayData? = nil
    @State private var dialogDay: SandboxDayData? = nil
    @State private var showDialog = false
    @State private var pagerDay: SandboxDayData? = nil
    @State private var pushedEntry: SandboxCoordEntry? = nil

    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if let days {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        fixtureNote
                        weekdayHeader
                        monthGrid(days: days)
                    }
                    .padding(16)
                }
            } else {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.white)
        .navigationTitle("同日複数コーデUI")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        // 案: シート — 複数日のみ日別一覧のハーフモーダルを挟む (本命)
        .sheet(item: $sheetDay) { day in
            DayOutfitsSheet(day: day) { entry in
                sheetDay = nil
                pushedEntry = entry
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // 案: ダイアログ — 既存の予定コーデと同じ confirmationDialog (サムネ無しが弱点)
        .confirmationDialog(
            dialogDay.map { "\(SandboxMultiCoordFixture.month)月\($0.day)日のコーデ \($0.records.count)件" } ?? "",
            isPresented: $showDialog,
            titleVisibility: .visible,
            presenting: dialogDay
        ) { day in
            ForEach(Array(day.records.enumerated()), id: \.element.id) { index, entry in
                Button("\(index + 1)枚目 (\(entry.registeredAt) 登録)") {
                    pushedEntry = entry
                }
            }
            if day.hasPlanned {
                Button("予定コーデを見る") {}
            }
            Button("キャンセル", role: .cancel) {}
        }
        // 案: ページャ — 選択を挟まず全件を横スワイプで眺める (タップ数最小)
        .fullScreenCover(item: $pagerDay) { day in
            DayOutfitsPager(day: day) { pagerDay = nil }
        }
        // 遷移先 (本番では path.append(.coordinateDetail(...)) の push になる)
        .sheet(item: $pushedEntry) { entry in
            SandboxCoordDetailMock(entry: entry)
        }
    }

    // MARK: - データ読み込み

    private func load() async {
        switch dataSource {
        case .mock(let delay):
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            days = SandboxMultiCoordFixture.mockDays()
        case .real:
            // 実uidで実APIを叩く。現行APIは同日1件に潰すため複数日は出ない (退行が無いことの確認用)。
            // 本番実装と同じ Dictionary(grouping:) で day -> [記録] にまとめる。
            let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
            let comps = Calendar.current.dateComponents([.year, .month], from: Date())
            let year = comps.year ?? SandboxMultiCoordFixture.year
            let month = comps.month ?? SandboxMultiCoordFixture.month
            guard !uid.isEmpty,
                  let result = try? await CoordinateListClient().get(uid: uid, year: year, month: month),
                  case .success(let responses) = result else {
                days = []
                return
            }
            let grouped = Dictionary(grouping: responses.filter { $0.displayImageURL != nil }, by: \.day)
            let numDays = responses.map(\.day).max() ?? 31
            days = (1...numDays).map { day in
                let records = (grouped[day] ?? []).enumerated().map { index, resp in
                    SandboxCoordEntry(
                        id: resp.id ?? "\(day)-\(index)",
                        imagePath: resp.displayImageURL ?? "",
                        registeredAt: "--:--"
                    )
                }
                return SandboxDayData(day: day, records: records, hasPlanned: false)
            }
        }
    }

    // MARK: - コントロール

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("セル表現", selection: $cellVariant) {
                ForEach(CellVariant.allCases) { v in Text(v.rawValue).tag(v) }
            }
            .pickerStyle(.segmented)
            Picker("選択UI", selection: $selectVariant) {
                ForEach(SelectVariant.allCases) { v in Text(v.rawValue).tag(v) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                Text("セル高 \(Int(cellHeight))pt")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Slider(value: $cellHeight, in: 30...90, step: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var fixtureNote: some View {
        Text("4日=2件 / 12日=3件 / 18日=5件 / 21日=記録2件+予定 / 26日=予定のみ。1件の日は従来通り即遷移、複数の日のみ選択UIを挟む。")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    // MARK: - 月グリッド

    private var weekdayHeader: some View {
        HStack(spacing: 5) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { i, wd in
                Text(wd)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(i == 0 ? Color.red.opacity(0.65) : i == 6 ? Color.blue.opacity(0.65) : Color.gray.opacity(0.55))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// 月初の曜日オフセットを含む週配列 ([Int?] の7要素、nil = 月外)
    private func weeks(dayCount: Int) -> [[Int?]] {
        let calendar = Calendar(identifier: .gregorian)
        let comps = DateComponents(year: SandboxMultiCoordFixture.year, month: SandboxMultiCoordFixture.month, day: 1)
        let firstWeekday = calendar.date(from: comps).map { calendar.component(.weekday, from: $0) } ?? 1
        var cells: [Int?] = Array(repeating: nil, count: firstWeekday - 1)
        cells.append(contentsOf: (1...dayCount).map { Optional($0) })
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    private func monthGrid(days: [SandboxDayData]) -> some View {
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0) })
        return VStack(spacing: 5) {
            ForEach(Array(weeks(dayCount: days.count).enumerated()), id: \.offset) { _, week in
                HStack(spacing: 5) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day, let data = byDay[day] {
                            dayCell(data: data)
                                .frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: cellHeight)
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(data: SandboxDayData) -> some View {
        Button {
            Haptic.impact(.soft)
            onTapDay(data)
        } label: {
            ZStack {
                if let first = data.records.first {
                    cellPhoto(data: data, first: first)

                    dayNumber(data.day)

                    // 記録が複数ある日のみ右上にインジケータ (左上=日付, 右下=予定の時計と役割分担)
                    if data.records.count > 1, cellVariant != .stack {
                        multiBadge(count: data.records.count)
                    }

                    // 記録がある日に予定も併存する場合は既存の時計アイコンを右下に併置
                    if data.hasPlanned {
                        clockIcon
                    }
                } else if data.hasPlanned {
                    // 予定のみの日: 既存表現 (破線枠 + 時計) を踏襲
                    coordinateImage(from: SandboxMultiCoordFixture.plannedImagePath)
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: cellHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.black.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        )
                    dayNumber(data.day)
                    clockIcon
                } else {
                    Color.clear
                    Text("\(data.day)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
            .frame(height: cellHeight)
        }
        .buttonStyle(.plain)
        .disabled(data.records.isEmpty && !data.hasPlanned)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: data))
        .accessibilityHint(data.records.count > 1 ? "ダブルタップでこの日のコーデ一覧を表示" : "")
    }

    /// セル写真部。C案 (ずらし重ね) のみ2枚目を背後にのぞかせる
    @ViewBuilder
    private func cellPhoto(data: SandboxDayData, first: SandboxCoordEntry) -> some View {
        if cellVariant == .stack, data.records.count > 1, let second = data.records.dropFirst().first {
            ZStack {
                coordinateImage(from: second.imagePath)
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: cellHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .offset(x: 3, y: 3)
                coordinateImage(from: first.imagePath)
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: cellHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 1))
                    .offset(x: -1, y: -1)
            }
        } else {
            coordinateImage(from: first.imagePath)
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: cellHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func dayNumber(_ day: Int) -> some View {
        Text("\(day)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(4)
    }

    private var clockIcon: some View {
        Image(systemName: "clock.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(4)
    }

    /// 右上の複数件インジケータ。明るい写真でも読めるよう半透明黒スクリムを敷く。
    /// セルが低い時 (40pt未満) は数字を落としてアイコンのみにする。
    private func multiBadge(count: Int) -> some View {
        HStack(spacing: 2) {
            if cellVariant == .badge {
                Image(systemName: "square.on.square.fill")
                    .font(.system(size: 8, weight: .bold))
            }
            if cellVariant == .count || cellHeight >= 40 {
                Text(count > 9 ? "9+" : "\(count)")
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
        .accessibilityHidden(true)
    }

    private func accessibilityLabel(for data: SandboxDayData) -> String {
        var label = "\(SandboxMultiCoordFixture.month)月\(data.day)日"
        if data.records.count > 1 {
            label += "、コーデ\(data.records.count)件"
        } else if data.records.count == 1 {
            label += "、コーデ1件"
        }
        if data.hasPlanned { label += "、予定あり" }
        return label
    }

    // MARK: - タップ分岐

    private func onTapDay(_ data: SandboxDayData) {
        // 1件の日 (+予定のみの日) は従来通り即遷移。複数の日だけ選択UIを挟む
        if data.records.count <= 1 && !(data.records.count == 1 && data.hasPlanned) {
            if let first = data.records.first {
                pushedEntry = first
            } else if data.hasPlanned {
                // 予定のみ: 本番では既存の confirmationDialog (詳細/削除)
                dialogDay = data
                showDialog = true
            }
            return
        }
        switch selectVariant {
        case .sheet:
            sheetDay = data
        case .dialog:
            dialogDay = data
            showDialog = true
        case .pager:
            pagerDay = data
        }
    }

    @ViewBuilder
    private func coordinateImage(from path: String) -> some View {
        if path.hasPrefix("http"), let url = URL(string: path) {
            KFImage(url).resizable()
        } else {
            Image(path).resizable()
        }
    }
}

// MARK: - 案: 日別一覧シート (本命)

/// 複数コーデの日をタップした時のハーフモーダル。
/// サムネイル+登録時刻で選び、予定コーデも同じシートに合流させる
/// (現状の「記録がある日は予定が不可視」問題をここで解消する)。
private struct DayOutfitsSheet: View {
    let day: SandboxDayData
    let onSelect: (SandboxCoordEntry) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("この日のコーデ \(day.records.count)件")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(Array(day.records.enumerated()), id: \.element.id) { index, entry in
                                recordTile(entry: entry, index: index)
                            }
                        }
                    }

                    if day.hasPlanned {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("予定コーデ")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            plannedRow
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("\(SandboxMultiCoordFixture.month)月\(day.day)日")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func recordTile(entry: SandboxCoordEntry, index: Int) -> some View {
        Button {
            Haptic.impact(.soft)
            onSelect(entry)
        } label: {
            VStack(spacing: 4) {
                tileImage(entry.imagePath)
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(3 / 4, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("\(entry.registeredAt) 登録")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(index + 1)枚目、\(entry.registeredAt)登録")
    }

    private var plannedRow: some View {
        HStack(spacing: 10) {
            tileImage(SandboxMultiCoordFixture.plannedImagePath)
                .scaledToFill()
                .frame(width: 44, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.black.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("まだ着ていない予定コーデ")
                    .font(.system(size: 13, weight: .semibold))
                Text("本番では既存の「詳細を見る / 予定から削除」に接続")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gray.opacity(0.5))
        }
        .padding(10)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func tileImage(_ path: String) -> some View {
        if path.hasPrefix("http"), let url = URL(string: path) {
            KFImage(url).resizable()
        } else {
            Image(path).resizable()
        }
    }
}

// MARK: - 案: ページャ (次点)

/// 選択を挟まず、その日の全件を横スワイプで眺める案。
/// タップ数最小だが「選ぶ」より「順に見る」体験になる。
private struct DayOutfitsPager: View {
    let day: SandboxDayData
    let onClose: () -> Void

    @State private var page = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                ForEach(Array(day.records.enumerated()), id: \.element.id) { index, entry in
                    VStack(spacing: 12) {
                        pagerImage(entry.imagePath)
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 24)
                        Text("\(index + 1) / \(day.records.count) ・ \(entry.registeredAt) 登録")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle("\(SandboxMultiCoordFixture.month)月\(day.day)日のコーデ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { onClose() }
                }
            }
        }
    }

    @ViewBuilder
    private func pagerImage(_ path: String) -> some View {
        if path.hasPrefix("http"), let url = URL(string: path) {
            KFImage(url).resizable()
        } else {
            Image(path).resizable()
        }
    }
}

// MARK: - 遷移先モック

/// 本番では ViewType.coordinateDetail への push に置き換わる
private struct SandboxCoordDetailMock: View {
    let entry: SandboxCoordEntry

    var body: some View {
        VStack(spacing: 16) {
            Group {
                if entry.imagePath.hasPrefix("http"), let url = URL(string: entry.imagePath) {
                    KFImage(url).resizable()
                } else {
                    Image(entry.imagePath).resizable()
                }
            }
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            Text("本番では coordinateDetail へ push (\(entry.id))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
        .presentationDetents([.large])
    }
}

// MARK: - Previews

#Preview("Mock (複数日あり)") {
    NavigationStack {
        CalendarMultiCoordSandboxView(dataSource: .mock(delay: 0))
    }
}

#Preview("Mock 遅延 1.5s") {
    NavigationStack {
        CalendarMultiCoordSandboxView(dataSource: .mock(delay: 1.5))
    }
}

#Preview("実API (現行は1日1件)") {
    NavigationStack {
        CalendarMultiCoordSandboxView(dataSource: .real)
    }
}
