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
    let coordinateForDate: (Int) -> CoordinateRecommend?
    let isLoadingForDate: (Int) -> Bool
    let onAddCoordinate: (Int) -> Void

    // アニメーション用
    @Namespace private var calendarAnimation

    // レイアウト定数
    private let cardWidth: CGFloat = 280
    private let cardSpacing: CGFloat = 16

    var body: some View {
        VStack(spacing: 12) {
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

            // 相対日付テキスト
//            Text(relativeDateText)
//                .font(.system(size: 18, weight: .bold))
//                .padding(.top, 20)

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
        WeeklyCoordinateCardView(
            dayString: item.dayString,
            coordinate: coordinateForDate(item.id),
            isLoading: isLoadingForDate(item.id),
            onAddCoordinate: { onAddCoordinate(item.id) }
        )
    }
}

// MARK: - Coordinate Card with Flip Animation

private struct WeeklyCoordinateCardView: View {
    let dayString: String
    let coordinate: CoordinateRecommend?
    let isLoading: Bool
    let onAddCoordinate: () -> Void

    @State private var isFlipped = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 裏面: 既存のレイアウト（グリッド + アイテムリスト）
            if let coordinate = coordinate {
                VStack(spacing: 0) {
                    // 上半分: アイテムグリッド
                    VStack(spacing: 8) {
                        Text("\(dayString)日のコーディネート")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)

                        imageGridView(gridItems: coordinate.gridItems)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }
                    .frame(height: 250)

                    // 下半分: アイテムリスト
                    Divider()
                        .padding(.horizontal, 16)
                    coordinateItemsList(coordinate: coordinate)
                        .frame(height: 250)
                }
                .rotation3DEffect(
                    .degrees(isFlipped ? 360 : 180),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 1 : 0)
            }

            // 表面: コーディネート全体画像
            if let coordinate = coordinate {
                coordinateImageView(path: coordinate.coordinate_image_path)
                    .padding(20)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .opacity(isFlipped ? 0 : 1)
            }

            // ローディング状態
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            // コーデ未追加状態
            if coordinate == nil && !isLoading {
                VStack {
                    Spacer()
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
                    Spacer()
                }
            }

            // 反転ボタン（常に最前面）
            if coordinate != nil {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isFlipped.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(16)
            }
        }
        .frame(width: 280, height: 500)
        .background(.white)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(.gray.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func coordinateImageView(path: String) -> some View {
        FirebaseStorageImage(path: path)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(contentMode: .fit)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func imageGridView(gridItems: [GridItemInfo]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<min(4, gridItems.count), id: \.self) { index in
                let item = gridItems[index]
                if !item.imagePath.isEmpty {
                    ZStack(alignment: .topLeading) {
                        // 背景画像
                        FirebaseStorageImage(path: item.imagePath)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                            .background(Color.gray.opacity(0.1))

                        // 左上のアイコン
                        Image(systemName: item.iconName)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // プレースホルダー
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
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

        if let outer = coordinate.outer, !outer.name.isEmpty {
            items.append(outer.name)
        }

        if let tops = coordinate.tops, !tops.name.isEmpty {
            items.append(tops.name)
        }

        if let bottoms = coordinate.bottoms, !bottoms.name.isEmpty {
            items.append(bottoms.name)
        }

        if let shoes = coordinate.shoes, !shoes.name.isEmpty {
            items.append(shoes.name)
        }

        if let accessories = coordinate.accessories, !accessories.name.isEmpty {
            items.append(accessories.name)
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
}

// MARK: - Helper Views for WeeklyPlannerContent

extension WeeklyPlannerContent {}
