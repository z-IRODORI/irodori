//
//  TomorrowPlannerView.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/19.
//

import SwiftUI

struct TomorrowPlannerView: View {
    @Binding var path: [ViewType]
    @State private var viewModel: TomorrowPlannerViewModel = .init()
    @State private var showResetDialog = false

    private let cardWidth: CGFloat = 280

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // タイトル
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("明日のコーデ提案")
                            .font(.system(size: 20, weight: .bold))
                        Text("過去に登録したアイテムやコーデから提案します")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // リセットボタン
                    if !viewModel.coordinates.isEmpty {
                        Button(action: { showResetDialog = true }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 選択アイテム表示
                if let item = viewModel.selectCoordinateItem {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Text("選択したアイテム")
                                .font(.system(size: 14, weight: .bold))
                            Button(action: { viewModel.showItemPicker() }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            CachedAsyncImage(
                                url: item.image_url.flatMap { URL(string: $0) }
                            ) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                            Text(item.category)
                                .font(.system(size: 16))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // 表示モード切り替えタブ
                if !viewModel.coordinates.isEmpty {
                    Picker("", selection: $viewModel.displayMode) {
                        Text("カード").tag(TomorrowPlannerViewModel.DisplayMode.card)
                        Text("一覧").tag(TomorrowPlannerViewModel.DisplayMode.grid)
                    }
                    .pickerStyle(.segmented)
                }

                // コーディネートカード
                if viewModel.displayMode == .card {
                    GeometryReader { proxy in
                        let margin = (proxy.size.width - cardWidth) / 2
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack {
                                CoordinateCardView(
                                    dayString: tomorrowDayString(),
                                    coordinates: viewModel.coordinates,
                                    isLoading: viewModel.isLoading,
                                    initialPage: viewModel.selectedCoordinateIndex,
                                    onAddCoordinateRandom: {
                                        Task { await viewModel.addCoordinateRandom() }
                                    },
                                    onAddCoordinateByItem: {
                                        viewModel.showItemPicker()
                                    },
                                    onReset: {
                                        showResetDialog = true
                                    }
                                )
                            }
                            .padding(.horizontal, margin)
                        }
                        .scrollDisabled(true)
                    }
                    .frame(height: 520)
                } else {
                    CoordinateGridView(
                        coordinates: viewModel.coordinates,
                        onTapCoordinate: { index in
                            withAnimation {
                                viewModel.switchToCardMode(at: index)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { path.removeLast() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                }
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingItemPicker },
            set: { viewModel.showingItemPicker = $0 }
        )) {
            ClosetItemPickerView(
                closetItems: viewModel.closetItems,
                isLoading: viewModel.isLoadingCloset,
                onSelect: { closetItem in
                    Task {
                        await viewModel.selectAndRecommend(closetItem: closetItem)
                    }
                }
            )
        }
        .confirmationDialog("リセット確認", isPresented: $showResetDialog) {
            Button("リセットする", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.reset()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("コーデ提案と選択したアイテムをリセットしますか？")
        }
    }

    // MARK: - Helper

    private func tomorrowDayString() -> String {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else { return "" }
        return tomorrow.formatted(.dateTime.day())
    }
}

#Preview {
    TomorrowPlannerView(path: .constant([]))
}
