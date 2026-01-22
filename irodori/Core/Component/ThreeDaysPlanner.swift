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
    let recommendedCoordinates: [CoordinateRecommend]
    let isLoading: Bool
    let onAddCoordinate: () -> Void

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
        let hasCoordinate = coordinateForItem(item) != nil

        return VStack(spacing: 0) {
            // 上半分: コーデ画像エリア
            VStack {
                Spacer()
                Text("\(item.dayString)日のコーディネート")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                if isLoading {
                    ProgressView()
                        .padding()
                } else if !hasCoordinate {
                    Button {
                        onAddCoordinate()
                    } label: {
                        Label("コーデを追加", systemImage: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(.black)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .frame(height: hasCoordinate ? 250 : 500)

            // 下半分: アイテムリスト
            if let coordinate = coordinateForItem(item) {
                coordinateItemsList(coordinate: coordinate)
                    .frame(height: 250)
            }
        }
        .frame(width: cardWidth, height: 500)
        .background(.white)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(.gray.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    private func coordinateForItem(_ item: CalendarData) -> CoordinateRecommend? {
        guard item.id < recommendedCoordinates.count else { return nil }
        return recommendedCoordinates[item.id]
    }

    @ViewBuilder
    private func coordinateItemsList(coordinate: CoordinateRecommend) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("アイテム")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    let items = buildItemList(coordinate: coordinate)
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        coordinateItemRow(category: item)
                        if index < items.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildItemList(coordinate: CoordinateRecommend) -> [String] {
        var items: [String] = []

        if !coordinate.outer.isEmpty {
            items.append(coordinate.outer)
        }

        items.append("トップス")
        items.append(coordinate.bottoms)
        items.append(coordinate.shoes)

        if !coordinate.accessories.isEmpty {
            let accessoryList = coordinate.accessories.split(separator: " ").map { String($0) }
            items.append(contentsOf: accessoryList)
        }

        return items
    }

    private func coordinateItemRow(category: String) -> some View {
        let itemCategory = ItemCategory(from: category)

        return HStack(spacing: 12) {
            Image(systemName: itemCategory.iconName)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 32)

            Text(category)
                .font(.system(size: 14))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.vertical, 8)
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
