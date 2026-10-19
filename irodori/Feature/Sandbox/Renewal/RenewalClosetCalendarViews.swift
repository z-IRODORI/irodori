//
//  RenewalClosetCalendarViews.swift
//  irodori - Sandbox
//
//  クローゼットタブ (手持ちアイテム一覧 + 「この服を軸にコーデを組む」導線) と
//  カレンダータブ (「今日着る」で決めた予定・写真発掘で埋まった過去の着用記録)。
//

import SwiftUI

// MARK: - クローゼット

struct RenewalClosetView: View {
    let store: RenewalStore
    var onBuildAround: (RenewalOwnedItem) -> Void
    var onOpenRegister: () -> Void

    @State private var focused: RenewalOwnedItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.state.closet.isEmpty {
                    ContentUnavailableView {
                        Label("まだ手持ちの服がありません", systemImage: "hanger")
                    } description: {
                        Text("写真フォルダや定番から教えると、相棒が手持ち服を主役にした提案を始めます。")
                    } actions: {
                        Button("服を登録する", action: onOpenRegister)
                            .buttonStyle(RenewalPrimaryButtonStyle())
                            .frame(maxWidth: 220)
                    }
                    .padding(.top, 40)
                } else {
                    Text("\(store.state.closet.count)着 ・ \(store.familySummary())が中心")
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.muted)
                    ForEach(RenewalCategory.allCases) { category in
                        let items = store.state.closet.filter { $0.category == category }
                        if !items.isEmpty {
                            RenewalSectionTitle(title: "\(category.label) (\(items.count))")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                                ForEach(items) { item in
                                    Button {
                                        focused = item
                                    } label: {
                                        VStack(spacing: 4) {
                                            RenewalItemTile(staple: item.staple, size: 84)
                                            Text(caption(item))
                                                .font(.system(size: 11))
                                                .foregroundStyle(RenewalTokens.muted)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(RenewalTokens.edge)
        }
        .background(RenewalTokens.ground)
        .navigationTitle("クローゼット")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(focused?.name ?? "", isPresented: Binding(get: { focused != nil }, set: { if !$0 { focused = nil } }), titleVisibility: .visible) {
            if let item = focused {
                Button("この服を軸に今日のコーデを組む") {
                    onBuildAround(item)
                    focused = nil
                }
            }
            Button("閉じる", role: .cancel) { focused = nil }
        }
    }

    private func caption(_ item: RenewalOwnedItem) -> String {
        let count = store.wearCount(item.id)
        if item.addedDay >= store.state.today - 2 { return "新着" }
        return count > 0 ? "着用\(count)回" : "まだ着ていない"
    }
}

// MARK: - カレンダー

struct RenewalCalendarView: View {
    let store: RenewalStore

    @State private var monthOffset = 0
    @State private var selectedDay: Int?

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ja_JP")
        return c
    }

    private var monthStart: Date {
        let today = store.date(of: store.state.today)
        let comps = calendar.dateComponents([.year, .month], from: today)
        let first = calendar.date(from: comps) ?? today
        return calendar.date(byAdding: .month, value: monthOffset, to: first) ?? first
    }

    private var days: [Int?] {
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let leading = calendar.component(.weekday, from: monthStart) - 1
        let startDay = store.day(of: monthStart)
        return Array(repeating: nil, count: leading) + range.map { startDay + $0 - 1 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                monthHeader
                weekdayHeader
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day { cell(day) } else { Color.clear.frame(height: 58) }
                    }
                }
                if let selectedDay {
                    dayDetail(selectedDay)
                }
            }
            .padding(RenewalTokens.edge)
        }
        .background(RenewalTokens.ground)
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if selectedDay == nil { selectedDay = store.state.today } }
    }

    private var monthHeader: some View {
        HStack {
            Button { monthOffset -= 1 } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("前の月")
            Spacer()
            Text(monthTitle)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Button { monthOffset += 1 } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("次の月")
        }
        .foregroundStyle(RenewalTokens.ink)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: monthStart)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { w in
                Text(w)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func cell(_ day: Int) -> some View {
        let record = store.wear(on: day)
        let isToday = day == store.state.today
        let isSelected = day == selectedDay
        let staples = record?.itemIDs.compactMap { RenewalStaple.find($0) } ?? []
        return Button {
            Haptic.selection()
            selectedDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: store.date(of: day)))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isToday ? .white : RenewalTokens.ink)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(isToday ? RenewalTokens.primaryFill : Color.clear))
                HStack(spacing: 2) {
                    ForEach(staples.prefix(3)) { s in
                        Circle()
                            .fill(s.color)
                            .overlay(Circle().stroke(RenewalTokens.controlBorder, lineWidth: s.isLight ? 0.5 : 0))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(height: 8)
                .opacity(day > store.state.today ? 0.5 : 1)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(isSelected ? RenewalTokens.surface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? RenewalTokens.ink : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(store.dateLabel(day))\(record == nil ? "、記録なし" : "、\(staples.map(\.name).joined(separator: "と"))")")
    }

    private func dayDetail(_ day: Int) -> some View {
        let record = store.wear(on: day)
        let staples = record?.itemIDs.compactMap { RenewalStaple.find($0) } ?? []
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.dateLabel(day)).font(.system(size: 15, weight: .semibold))
                Spacer()
                if let record {
                    Text(sourceLabel(record, day: day))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                }
            }
            if staples.isEmpty {
                Text(day > store.state.today ? "まだ予定はありません。ホームの「明日」「週末」から決められます。" : "この日の記録はありません")
                    .font(.system(size: 13))
                    .foregroundStyle(RenewalTokens.muted)
            } else {
                HStack(spacing: 12) {
                    RenewalExampleImage(
                        recipe: RenewalRecipe(ownedItems: [], missingItems: staples, kind: .zero, heroID: nil, mainFamily: staples[0].family),
                        height: 150
                    )
                    .frame(width: 110)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(staples) { s in
                            HStack(spacing: 8) {
                                RenewalItemTile(staple: s, size: 32, owned: store.owns(s), showName: false)
                                Text(s.name).font(.system(size: 13, weight: .medium))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .renewalCard()
    }

    private func sourceLabel(_ record: RenewalWearRecord, day: Int) -> String {
        switch record.source {
        case .decided: return day > store.state.today ? "予定 (相棒の提案から決定)" : "相棒の提案から決定"
        case .photo: return "写真フォルダから"
        case .camera: return "全身スナップ"
        }
    }
}
