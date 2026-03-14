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
    let selectCoordinateItemForDate: (Int) -> SelectCoordinateItem?
    let onSelectDate: (Int) -> Void
    let isCurrentMonth: (Date) -> Bool
    let coordinatesForDate: (Int) -> [CoordinateRecommend]
    let isLoadingForDate: (Int) -> Bool
    let onAddCoordinateRandom: (Int) -> Void
    let onAddCoordinateByItem: (Int) -> Void
    let onChangeItem: () -> Void
    let onReset: (Int) -> Void

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

            if let selectedID = selectedDateID, let item = selectCoordinateItemForDate(selectedID) {
                HStack(spacing: 12) {
                    Text("選択したアイテム")
                        .font(.system(size: 14, weight: .bold))
                    Button(action: onChangeItem) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    CachedAsyncImage(
                        url: item.image_url.flatMap { URL(string: $0) }
                    ) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    Text(item.category)
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            }


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
        CoordinateCardView(
            dayString: item.dayString,
            coordinates: coordinatesForDate(item.id),
            isLoading: isLoadingForDate(item.id),
            onAddCoordinateRandom: { onAddCoordinateRandom(item.id) },
            onAddCoordinateByItem: { onAddCoordinateByItem(item.id) },
            onReset: { onReset(item.id) }
        )
    }
}

// MARK: - Coordinate Card with Flip Animation

struct CoordinateCardView: View {
    let dayString: String
    let coordinates: [CoordinateRecommend]
    let isLoading: Bool
    let initialPage: Int
    let onAddCoordinateRandom: () -> Void
    let onAddCoordinateByItem: () -> Void
    let onReset: () -> Void

    init(
        dayString: String,
        coordinates: [CoordinateRecommend],
        isLoading: Bool,
        initialPage: Int = 0,
        onAddCoordinateRandom: @escaping () -> Void,
        onAddCoordinateByItem: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.dayString = dayString
        self.coordinates = coordinates
        self.isLoading = isLoading
        self.initialPage = initialPage
        self.onAddCoordinateRandom = onAddCoordinateRandom
        self.onAddCoordinateByItem = onAddCoordinateByItem
        self.onReset = onReset
    }

    @State private var isFlipped = false
    @State private var currentCoordinatePage = 0  // コーディネートのページ
    @State private var currentItemPage = 0        // アイテムリストのページ
    @State private var isTransitioning = false    // コーディネート切り替え中のローディング
    @State private var pulseScale: CGFloat = 1.0  // ローディングパルスアニメーション用

    // 現在のコーディネート
    private var currentCoordinate: CoordinateRecommend? {
        guard !coordinates.isEmpty, currentCoordinatePage < coordinates.count else { return nil }
        return coordinates[currentCoordinatePage]
    }

    // ページングの設定（アイテムリスト用）
    private let itemsPerPage = 3

    var body: some View {
        ZStack {
            if let coordinate = currentCoordinate {
                VStack(spacing: 4) {
                    // タイトル + ページングボタン
                    pagingHeader(title: isFlipped ? "アイテム" : "コーディネート", coordinate: coordinate)
                    // ページインジケーター
                    pagingIndicator(coordinate: coordinate)
                    coordinateBackView(coordinate: coordinate)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 24)
            }

            // ローディング状態
            if isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.gray.opacity(0.35))
                        .scaleEffect(pulseScale)
                    Text("コーデを選択中...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        pulseScale = 1.18
                    }
                }
                .onDisappear {
                    pulseScale = 1.0
                }
            }

            // コーデ未追加状態
            if currentCoordinate == nil && !isLoading {
                VStack(spacing: 24) {
                    Button {
                        onAddCoordinateRandom()
                    } label: {
                        Label("ランダム", systemImage: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(.black)
                            .clipShape(Capsule())
                    }

                    Button {
                        onAddCoordinateByItem()
                    } label: {
                        Label("アイテムから提案", systemImage: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(.black)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(width: 280, height: 500)
        .background(.white)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(.gray.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottomTrailing) {
            // 反転ボタン（常に最前面）
            if currentCoordinate != nil {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isFlipped.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(16)
            }
        }
        .onChange(of: coordinates.count) { _, _ in
            currentCoordinatePage = 0  // コーディネート配列が変わったらページをリセット
            currentItemPage = 0
        }
        .onAppear {
            if !coordinates.isEmpty {
                currentCoordinatePage = min(initialPage, coordinates.count - 1)
            }
        }
    }

    @ViewBuilder
    private func coordinateBackView(coordinate: CoordinateRecommend) -> some View {
        ZStack(alignment: .top) {
            // 裏面の内容
            VStack(spacing: 12) {
                // アイテム画像
                imageGridView(gridItems: coordinate.gridItems)
                    .padding(20)

                Divider()
                    .padding(.horizontal, 16)

                // アイテムリスト
                ScrollView {
                    itemsList(coordinate: coordinate)
                }
                .frame(maxHeight: 250)
            }
            .opacity(isFlipped ? 1 : 0)   // 裏表で表示の有無を切り替える

            // 表面
            // コーディネート全体画像
            coordinateImageView(path: coordinate.coordinate_image_path)
                .padding(20)
                .id(coordinate.coordinate_image_path)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .opacity(isFlipped ? 0 : 1)   // 裏表で表示の有無を切り替える
        }
    }

    // MARK: - 共通ペーシングUI

    @ViewBuilder
    private func pagingHeader(title: String, coordinate: CoordinateRecommend) -> some View {
        // 左右に同幅の領域を置き、中央のページングコントロールを常に中央に固定する
        let sideWidth: CGFloat = 60

        // 中央：ページングコントロール
        HStack(spacing: 12) {
            Button {
                withAnimation { goToPreviousCoordinate() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoToPreviousCoordinate() ? .black : .gray.opacity(0.3))
                    .frame(width: 28, height: 28)
            }
            .disabled(!canGoToPreviousCoordinate())

            Text(title)
                .fontWeight(.bold)

            Button {
                withAnimation { goToNextCoordinate() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoToNextCoordinate() ? .black : .gray.opacity(0.3))
                    .frame(width: 28, height: 28)
            }
            .disabled(!canGoToNextCoordinate())
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func pagingIndicator(coordinate: CoordinateRecommend) -> some View {
        let totalPages = coordinates.count

        if totalPages > 1 {
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { page in
                    Circle()
                        .fill(page == currentCoordinatePage ? Color.black : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    @ViewBuilder
    private func itemsList(coordinate: CoordinateRecommend) -> some View {
        let items = buildItemList(coordinate: coordinate)

        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                coordinateItemRow(category: item)
                if index < items.count - 1 {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - ページング制御（コーディネート）

    private func canGoToPreviousCoordinate() -> Bool {
        return currentCoordinatePage > 0
    }

    private func canGoToNextCoordinate() -> Bool {
        return currentCoordinatePage < coordinates.count - 1
    }

    private func goToPreviousCoordinate() {
        if currentCoordinatePage > 0 {
            isTransitioning = true
            currentCoordinatePage -= 1
        }
    }

    private func goToNextCoordinate() {
        if currentCoordinatePage < coordinates.count - 1 {
            isTransitioning = true
            currentCoordinatePage += 1
        }
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

    @ViewBuilder
    private func coordinateImageView(path: String) -> some View {
        ZStack {
            Group {
                if path.hasPrefix("http") {
                    CachedAsyncImage(url: URL(string: path)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray.opacity(0.15)
                    }
                    .onAppear { isTransitioning = false }
                } else {
                    FirebaseStorageImage(path: path, onLoaded: { isTransitioning = false })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if isTransitioning {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
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
//                    Image(systemName: "photo")
//                        .resizable()
//                        .background(Color.gray.opacity(0.1))
                    EmptyView()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Helper Views for ThreeDaysPlanner

extension ThreeDaysPlanner {
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
