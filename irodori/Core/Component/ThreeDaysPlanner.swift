//
//  WeeklyPlannner.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/03.
//

import SwiftUI

struct ThreeDaysPlanner: View {
    let calendarList: [CalendarData]
    @Binding var selectedDateID: Int?
    let relativeDateText: String
    let onSelectDate: (Int) -> Void
    let isCurrentMonth: (Date) -> Bool

    // アニメーション用
    @Namespace private var calendarAnimation

    // レイアウト定数
    private let cardWidth: CGFloat = 280
    private let cardSpacing: CGFloat = 16

    var body: some View {
        VStack(spacing: 12) {
            // カレンダー部分
            Picker("", selection: $selectedDateID) {
                ForEach(calendarList) { item in
                    Text(relativeDateString(for: item))
                        .tag(item.id as Int?)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)

            // カルーセル部分
            GeometryReader { proxy in
                let margin = (proxy.size.width - cardWidth) / 2
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: cardSpacing) {
                        ForEach(calendarList) { item in
                            coordinateCard(for: item).id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, margin, for: .scrollContent)
                .scrollPosition(id: $selectedDateID)
                .scrollTargetBehavior(.viewAligned)
            }
            .frame(height: 520)
        }
    }

    private func coordinateCard(for item: CalendarData) -> some View {
        VStack {
            Spacer()
            Text("\(item.dayString)日のコーディネート")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            Button { /* 追加アクション */ } label: {
                Label("コーデを追加", systemImage: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.black)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .frame(width: cardWidth, height: 500)
        .background(.white)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(.gray.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    private func relativeDateString(for item: CalendarData) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: item.date)
        let diff = calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0
        switch diff {
        case 0: return "今日"
        case 1: return "明日"
        case 2: return "明後日"
        default: return item.dayString
        }
    }
}
