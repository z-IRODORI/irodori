//
//  CoordinateDetailView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import SwiftUI

extension CoordinateDetailResponse.CoordinateItem: Identifiable {}

struct CoordinateDetailView: View {
    @State var viewModel: CoordinateDetailViewModel
    @State private var coordinateImage: UIImage?
    /// タップされたアイテム (詳細シート表示用)
    @State private var selectedItem: CoordinateDetailResponse.CoordinateItem?
    let showHeader: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // fetch 結果に関わらず画像はプレースホルダとして表示する
                LargeCoordinateCardWithURL(
                    coordinateImageURL: viewModel.displayedImageURL,
                    currentSchedule: viewModel.coordinateDetail?.current_coordinate.date ?? "",
                    aiCatchphrase: viewModel.coordinateDetail?.ai_catchphrase ?? ""
                )

                // このコーデを一覧で「撮影画像 / 切り取り」どちらで表示するか (切り取りがある時だけ)
                if viewModel.hasCutout {
                    displayTypePicker
                }

                if let coordinateDetail = viewModel.coordinateDetail {
                    VStack(alignment: .leading, spacing: 12) {
                        PartnerIconImage(size: 50)
                        ReviewText(aiReviewComment: coordinateDetail.ai_review_comment)
                    }
                    .padding(.horizontal, 24)

                    // 着用アイテム (画像URLがあるもののみ)。タップでアイテム詳細シートへ
                    let items = coordinateDetail.items.filter { $0.item_image_path.hasPrefix("http") }
                    if !items.isEmpty {
                        itemsSection(items)
                    }
                } else if viewModel.isLoadingDetail {
                    ProgressView()
                        .padding(.top, 32)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("詳細を取得できませんでした")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await viewModel.fetchCoordinateDetail() }
                        } label: {
                            Text("再試行")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.black)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 32)
                }
            }
            .padding(.bottom, 100)
        }
        .overlay(alignment: .bottom) {
            Button(action: {
                AnalyticsLogger.shared.log(action: .recommendationRequested, parameters: [
                    "source": GAEventAction.coordinateDetail.rawValue,
                    "coordinate_id": viewModel.coordinateId
                ])
//                viewModel.tappedRecommendCoordinateButton()
                viewModel.tappedWillShowChatView()
            }) {
//                Text("おすすめのコーデ/アイテムを見る")
                Text("💬 相棒に質問する")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(.black)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $viewModel.willShowRecommendCoordinateView) {
            RecommendCoordinateView(viewModel: .init(recommendCoordinateClient: RecommendCoordinateClient()))
        }
        // アイテム詳細 (カテゴリ/カラー/名前/特徴 + このアイテムを使ったコーデ)
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(
                itemId: item.id,
                initialImageURL: item.item_image_path,
                initialTypeLabel: item.item_type
            )
        }
        .navigationDestination(isPresented: $viewModel.willShowChatView) {
            if let image = coordinateImage {
                ChatView(coordinateId: viewModel.coordinateDetail?.current_coordinate.id ?? UUID().uuidString, image: image)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.gray.opacity(0.08))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            if showHeader {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.coordinateDetail?.current_coordinate.date ?? "")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .task {
            AnalyticsLogger.shared.log(screen: .coordinateDetailScreenView, parameters: [
                "coordinate_id": viewModel.coordinateId
            ])
            await viewModel.onAppear()
            await loadCoordinateImage()
        }
    }
    
    /// 着用アイテムの横スクロール (v2 で生成した透過アイテム画像、legacy のトップス/ボトムス画像)
    private func itemsSection(_ items: [CoordinateDetailResponse.CoordinateItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("着用しているアイテム")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            VStack(spacing: 0) {
                                CachedAsyncImage(url: URL(string: item.item_image_path)!) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFit()
                                    } else if phase.error != nil {
                                        Image(systemName: "photo").foregroundStyle(.secondary)
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .frame(width: 96, height: 96)
                                .padding(10)

                                Text(item.item_type)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.bottom, 8)
                            }
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 一覧での表示画像を撮影/切り取りで切り替える (コーデごとに永続化)
    private var displayTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一覧での表示画像")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("一覧での表示画像", selection: Binding(
                get: { viewModel.currentDisplayType },
                set: { newValue in Task { await viewModel.setDisplayType(newValue) } }
            )) {
                Text("撮影画像").tag(CoordinateDisplayType.captured)
                Text("切り取り").tag(CoordinateDisplayType.cutout)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isUpdatingDisplayType)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadCoordinateImage() async {
        guard let url = URL(string: viewModel.displayedImageURL) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.coordinateImage = image
                }
            }
        } catch {
            print("Failed to load coordinate image: \(error)")
        }
    }
}
