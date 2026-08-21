//
//  ItemDetailSheet.swift
//  irodori
//
//  アイテム詳細 (カテゴリ/カラー/名前/特徴) と
//  「このアイテムを使ったコーデ」一覧を表示するシート。
//  データは GET /api/item/{item_id}/coordinates から取得する。
//

import SwiftUI

extension FashionReviewResponse.Item: Identifiable {}

struct ItemDetailSheet: View {
    let itemId: String
    /// フェッチ完了前に表示する初期情報 (一覧カードから引き継ぐ)
    var initialImageURL: String? = nil
    var initialTypeLabel: String? = nil
    var apiClient: ItemCoordinatesClientProtocol = ItemCoordinatesClient()

    @State private var detail: ItemCoordinatesResponse?
    @State private var loadFailed = false
    /// タップされたコーデ (シート内 NavigationStack で詳細へ push する)
    @State private var pushedCoordinate: ViewType.CoordinateDetailParams?
    /// アイテム画像タップで開く拡大ビューア
    @State private var showImageViewer = false

    private var imageURL: String? { detail?.image_url ?? initialImageURL }
    private var typeLabel: String? { detail?.item_type ?? initialTypeLabel }

    var body: some View {
        // コーデ詳細への遷移をシート内で完結させる (呼び出し元の path に依存しない)
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    itemHeader
                    if let description = detail?.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("特徴")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundStyle(.black)
                                .lineSpacing(3)
                        }
                    }
                    Divider()
                    coordinatesSection
                }
                .padding(24)
            }
            .background(.white)
            .navigationDestination(item: $pushedCoordinate) { params in
                CoordinateDetailView(
                    viewModel: .init(
                        coordinateId: params.coordinateId,
                        coordinateImageURL: params.coordinateImageURL,
                        coordinateDetailClient: CoordinateDetailClient()
                    ),
                    showHeader: params.showHeader
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    private var itemHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // 生成画像は背景透過PNGのため、薄グレー地に載せて輪郭を見せる
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.08))
                if let imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(10)
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, height: 140)
            .contentShape(Rectangle())
            // タップで拡大表示 (ピンチズーム対応)
            .onTapGesture {
                if imageURL != nil { showImageViewer = true }
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                if let imageURL {
                    ItemImageZoomViewer(imageURL: imageURL)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let typeLabel {
                    Text(typeLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.pink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.pink.opacity(0.1), in: Capsule())
                }
                Text(detail?.category ?? "アイテム")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                if let color = detail?.color, !color.isEmpty {
                    Text(color)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("このアイテムを使ったコーデ")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)

            if let detail {
                if detail.coordinates.isEmpty {
                    Text("まだこのアイテムを使ったコーデはありません")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(detail.coordinates) { coordinate in
                                coordinateCard(coordinate)
                            }
                        }
                    }
                }
            } else if loadFailed {
                HStack(spacing: 12) {
                    Text("読み込みに失敗しました")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("再試行") {
                        loadFailed = false
                        Task { await load() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .padding(.vertical, 12)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }

    private func coordinateCard(_ coordinate: ItemCoordinatesResponse.CoordinateSummary) -> some View {
        Button {
            pushedCoordinate = .init(
                coordinateId: coordinate.coordinate_id,
                coordinateImageURL: coordinate.displayImageURL,
                showHeader: true
            )
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                CachedAsyncImage(url: URL(string: coordinate.displayImageURL)!) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Color.gray.opacity(0.2)
                    } else {
                        Color.gray.opacity(0.08)
                    }
                }
                .frame(width: 110, height: 110 * 4 / 3)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(coordinate.date)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 110)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        do {
            let result = try await apiClient.get(itemId: itemId, uid: uid)
            switch result {
            case .success(let response):
                detail = response
            case .failure:
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }
    }
}

/// アイテム画像の拡大ビューア (ピンチズーム + ダブルタップ切替 + タップ/×で閉じる)
struct ItemImageZoomViewer: View {
    let imageURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .onTapGesture { dismiss() }

            if let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else if phase.error != nil {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(.gray)
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scale = scale > 1 ? 1 : 2.5
                        lastScale = scale
                    }
                }
                .padding(24)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.top, 8)
            .padding(.trailing, 12)
            .accessibilityLabel("閉じる")
        }
    }
}

#Preview {
    ItemDetailSheet(
        itemId: "item-1",
        initialTypeLabel: "アウター",
        apiClient: MockItemCoordinatesClient()
    )
}
