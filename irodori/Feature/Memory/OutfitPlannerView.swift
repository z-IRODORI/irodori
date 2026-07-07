//
//  OutfitPlannerView.swift
//  irodori
//
//  まとめて提案: 1週間 / 1ヶ月 / カスタム日数分のコーデを一括提案し、
//  日ごとに入替・除外して納得したら「この内容でカレンダーに追加」で
//  予定コーデ (calendar_outfits) へ一括保存する。承認するまで保存しない。
//
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

    struct PlanDayState: Identifiable {
        let date: String                            // YYYY-MM-DD
        let weather: DailyRecommendationWeather?
        var candidates: [DailyRecommendationItem]   // [本命, 入替候補...]
        var selectedIndex: Int = 0
        var isExcluded: Bool = false
        var hasExistingPlan: Bool = false
        var id: String { date }
        var selected: DailyRecommendationItem {
            candidates[min(selectedIndex, candidates.count - 1)]
        }
    }

    var period: Period = .week
    var customDays: Int = 5
    var startDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    var isLoading = false
    var isSaving = false
    var days: [PlanDayState] = []

    var daysCount: Int {
        switch period {
        case .week: return 7
        case .month: return 30
        case .custom: return customDays
        }
    }

    var includedCount: Int { days.filter { !$0.isExcluded }.count }

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
        defer { isLoading = false }

        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        let prefectureCode = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let startString = formatter.string(from: startDate)

        guard let result = try? await planClient.plan(
            uid: uid, gender: gender, days: daysCount,
            startDate: startString, prefectureCode: prefectureCode
        ), case .success(let response) = result, !response.days.isEmpty else {
            ToastManager.shared.show("コーデの提案に失敗しました。時間をおいて再度お試しください")
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
                selectedIndex: 0,
                isExcluded: exists,
                hasExistingPlan: exists
            )
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

    func swapCandidate(_ date: String) {
        guard let index = days.firstIndex(where: { $0.date == date }),
              days[index].candidates.count > 1 else { return }
        days[index].selectedIndex = (days[index].selectedIndex + 1) % days[index].candidates.count
    }

    func toggleExclude(_ date: String) {
        guard let index = days.firstIndex(where: { $0.date == date }) else { return }
        days[index].isExcluded.toggle()
    }

    func reset() {
        days = []
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

// MARK: - View

struct OutfitPlannerView: View {
    @Binding var path: [ViewType]
    @State private var viewModel = OutfitPlannerViewModel()
    @State private var editingDay: OutfitPlannerViewModel.PlanDayState? = nil

    var body: some View {
        Group {
            if viewModel.days.isEmpty {
                setupView
            } else {
                resultView
            }
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle("まとめて提案")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("相棒がコーデを考えています…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .sheet(item: $editingDay) { day in
            PlanDayEditSheet(
                day: currentState(of: day),
                onSwap: { viewModel.swapCandidate(day.date) },
                onToggleExclude: { viewModel.toggleExclude(day.date) }
            )
            .presentationDetents([.height(480)])
        }
    }

    // sheet 表示中も最新の選択状態を反映する
    private func currentState(of day: OutfitPlannerViewModel.PlanDayState) -> OutfitPlannerViewModel.PlanDayState {
        viewModel.days.first { $0.date == day.date } ?? day
    }

    // MARK: 条件設定

    private var setupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("期間を選ぶと、相棒がその日数分のコーデをまとめて提案します。気に入らない日は入替や除外ができます。")
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

    // MARK: 提案レビュー

    private var resultView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("気に入らない日は入替・除外できます")
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
                .padding(.top, 8)

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
                        ToastManager.shared.show("\(count)日分のコーデをカレンダーに追加しました", style: .normal)
                        path.removeLast()
                    }
                }
            }
        }
    }

    // 日カード (10日以下のリスト表示)
    private func dayCard(_ day: OutfitPlannerViewModel.PlanDayState) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(monthDayLabel(day.date))
                    .font(.system(size: 15, weight: .bold))
                Text(weekdayLabel(day.date))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46)

            KFImage(URL(string: day.selected.image_url))
                .placeholder { Color.gray.opacity(0.12) }
                .resizable()
                .scaledToFill()
                .frame(width: 78, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                if let weather = day.weather {
                    Text("\(weather.condition)・\(weather.min_temp)〜\(weather.max_temp)°C")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if day.hasExistingPlan {
                    Text(day.isExcluded ? "予定あり（この日はそのまま）" : "予定あり（上書きします）")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(day.isExcluded ? Color.secondary : Color.red)
                }
                HStack(spacing: 8) {
                    pillButton("入替", systemImage: "arrow.2.squarepath", disabled: day.isExcluded || day.candidates.count <= 1) {
                        viewModel.swapCandidate(day.date)
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
            Spacer(minLength: 0)
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

    // グリッド表示 (11日以上)。セルタップで編集シート
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
                    editingDay = day
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

// MARK: - グリッド用の日編集シート

private struct PlanDayEditSheet: View {
    let day: OutfitPlannerViewModel.PlanDayState
    let onSwap: () -> Void
    let onToggleExclude: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Text(titleLabel)
                .font(.system(size: 15, weight: .bold))
                .padding(.top, 18)

            KFImage(URL(string: day.selected.image_url))
                .placeholder { Color.gray.opacity(0.12) }
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(day.isExcluded ? 0.4 : 1)

            if let weather = day.weather {
                Text("\(weather.condition)・\(weather.min_temp)〜\(weather.max_temp)°C")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                sheetButton("入替", systemImage: "arrow.2.squarepath", disabled: day.isExcluded || day.candidates.count <= 1) {
                    onSwap()
                }
                sheetButton(
                    day.isExcluded ? "この日を戻す" : "この日は不要",
                    systemImage: day.isExcluded ? "plus.circle" : "minus.circle",
                    disabled: false
                ) {
                    onToggleExclude()
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
    }

    private var titleLabel: String {
        let parts = day.date.split(separator: "-")
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) {
            return "\(m)月\(d)日のコーデ"
        }
        return day.date
    }

    private func sheetButton(_ label: String, systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Label(label, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

#Preview {
    NavigationStack {
        OutfitPlannerView(path: .constant([]))
    }
}
