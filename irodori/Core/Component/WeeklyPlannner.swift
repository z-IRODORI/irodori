//
//  WeeklyPlannner.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/03.
//

import SwiftUI

struct WeeklyPlannerContent: View {
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
        VStack(spacing: 0) {
            // カレンダー部分
            HStack(spacing: 0) {
                ForEach(calendarList) { item in
                    Button {
                        onSelectDate(item.id)
                    } label: {
                        VStack(spacing: 12) {
                            Text(item.weekDayString).font(.system(size: 12)).foregroundStyle(.gray)
                            ZStack {
                                if selectedDateID == item.id {
                                    Circle().fill(.black).frame(width: 35, height: 35)
                                        .matchedGeometryEffect(id: "selection", in: calendarAnimation)
                                }
                                Text(item.dayString).font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(selectedDateID == item.id ? .white : .black)
                                    .opacity(isCurrentMonth(item.date) ? 1.0 : 0.3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)

            // 相対日付テキスト
            Text(relativeDateText)
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 20)

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
            .padding(.vertical, 20)
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
}
