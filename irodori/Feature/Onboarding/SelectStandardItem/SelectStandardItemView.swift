//
//  SelectStandardItemView.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/14.
//

import SwiftUI

struct SelectStandardItemView: View {
    @State private var viewModel = SelectStandardItemViewModel()
    @Environment(\.dismiss) var dismiss
    @Binding var path: [ViewType]
    let onSelect: ((StandardItem) -> Void)?
    let onComplete: (() -> Void)?
    @State private var showRecommendationsSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(
        path: Binding<[ViewType]> = .constant([]),
        onSelect: ((StandardItem) -> Void)? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self._path = path
        self.onSelect = onSelect
        self.onComplete = onComplete
    }

    var body: some View {
        print("🔍 [SelectStandardItemView] body called - isLoading: \(viewModel.isLoading), itemsCount: \(viewModel.items.count), onComplete: \(onComplete != nil)")
        return ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("再試行") {
                                Task {
                                    await viewModel.fetchItems()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 24)
                    } else if viewModel.items.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundStyle(.gray.opacity(0.3))
                            Text("アイテムが見つかりませんでした")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Button("再試行") {
                                Task {
                                    await viewModel.fetchItems()
                                }
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            if onComplete != nil {
                                Button("スキップ") {
                                    UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue)
                                    onComplete?()
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        filterBar

                        if viewModel.filteredItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.gray.opacity(0.4))
                                Text("条件に合うアイテムがありません")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Button("絞り込みを解除") {
                                    viewModel.resetFilters()
                                }
                                .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(viewModel.filteredItems) { item in
                                        itemCell(item: item)
                                    }
                                }
                                .padding(16)
                                .padding(.bottom, onSelect == nil ? 80 : 0)
                            }
                        }
                    }
                }

                // Bottom button (only show when onSelect is nil - bulk mode)
                if onSelect == nil && !viewModel.items.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                        HStack {
                            Text("\(viewModel.selectedItems.count)個選択中")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button(action: {
                                Task {
                                    await viewModel.registerSelectedItems()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if viewModel.isRegistering {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                        Text("登録中...")
                                            .font(.system(size: 16, weight: .semibold))
                                    } else {
                                        Text("登録")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                            }
                            .frame(minWidth: 120)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(
                                viewModel.isRegistering ? Color.gray.opacity(0.6) :
                                viewModel.selectedItems.isEmpty ? Color.gray.opacity(0.3) : Color.black
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .disabled(viewModel.selectedItems.isEmpty || viewModel.isRegistering)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                    }
                }
            }
            .navigationTitle("スタンダードアイテム")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(onComplete != nil)
            .toolbar {
                // 通常モード（onComplete が nil）の場合のみ「閉じる」ボタンを表示
                if onComplete == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await viewModel.fetchItems()
            }
            .onChange(of: viewModel.registrationSuccess) { _, success in
                if success {
                    if onComplete != nil {
                        // オンボーディングモード: NavigationStack で push
                        path.append(.recommendCoordinateByStandardItem(
                            ViewType.RecommendCoordinateParams(
                                results: viewModel.coordinateRecommendResults,
                                selectedItems: viewModel.selectedItemsForRecommend
                            )
                        ))

                        // UserDefaults にフラグを保存
                        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue)
                    } else {
                        // 通常モード: sheet で表示（既存の動作）
                        showRecommendationsSheet = true
                    }

                    viewModel.registrationSuccess = false  // リセット
                }
            }
            .sheet(isPresented: $showRecommendationsSheet) {
                NavigationStack {
                    RecommendCoordinateByStandardItemView(
                        results: viewModel.coordinateRecommendResults,
                        selectedItems: viewModel.selectedItemsForRecommend,
                        onComplete: nil
                    )
                }
            }
    }

    // MARK: - Filter UI

    private var filterBar: some View {
        VStack(spacing: 8) {
            Picker("性別", selection: Binding(
                get: { viewModel.selectedGender ?? "men" },
                set: { gender in
                    Task { await viewModel.selectGender(gender) }
                }
            )) {
                Text("メンズ").tag("men")
                Text("レディース").tag("women")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "すべて", isSelected: viewModel.filterMainCategory == nil) {
                        viewModel.selectMainCategory(nil)
                    }
                    ForEach(viewModel.availableMainCategories, id: \.self) { category in
                        filterChip(label: category, isSelected: viewModel.filterMainCategory == category) {
                            viewModel.selectMainCategory(
                                viewModel.filterMainCategory == category ? nil : category
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "全色", isSelected: viewModel.filterColor == nil) {
                        viewModel.filterColor = nil
                    }
                    ForEach(viewModel.availableColors, id: \.self) { color in
                        colorChip(color)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack {
                Text("\(viewModel.filteredItems.count)件")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.white)
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.black : Color.gray.opacity(0.12))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func colorChip(_ color: String) -> some View {
        let isSelected = viewModel.filterColor == color
        return Button(action: {
            viewModel.filterColor = isSelected ? nil : color
        }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Self.swatchColor(for: color))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 0.5))
                Text(color)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.black : Color.gray.opacity(0.12))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private static func swatchColor(for name: String) -> Color {
        switch name {
        case "ホワイト", "オフホワイト": return .white
        case "ブラック": return .black
        case "グレー": return .gray
        case "ダークグレー": return Color(white: 0.3)
        case "ネイビー": return Color(red: 0.10, green: 0.15, blue: 0.35)
        case "ベージュ": return Color(red: 0.90, green: 0.84, blue: 0.71)
        case "ブラウン": return .brown
        case "カーキ", "オリーブグリーン": return Color(red: 0.45, green: 0.47, blue: 0.30)
        case "ブルー": return .blue
        case "ライトブルー": return Color(red: 0.55, green: 0.78, blue: 0.95)
        case "インディゴ": return Color(red: 0.20, green: 0.25, blue: 0.45)
        case "レッド": return .red
        case "ピンク": return .pink
        case "イエロー": return .yellow
        case "オレンジ": return .orange
        case "グリーン": return .green
        default: return .gray.opacity(0.4)
        }
    }

    private func itemCell(item: StandardItem) -> some View {
        let isSelected = viewModel.isSelected(item)

        return Button(action: {
            if let onSelect = onSelect {
                // Single selection mode
                onSelect(item)
                dismiss()
            } else {
                // Multiple selection mode
                viewModel.toggleSelection(item)
            }
        }) {
            VStack(spacing: 8) {
                // 画像
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(url: URL(string: item.storage_url)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.15)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .clipped()

                    // Selection indicator
                    if onSelect == nil {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.black : Color.white)
                                .frame(width: 24, height: 24)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding(4)
                    }
                }

                // アイテム情報
                VStack(spacing: 2) {
                    Text(item.sub_category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.color)
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
            .padding(8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
