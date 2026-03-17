//
//  RecommendCoordinateByStandardItemView.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/14.
//

import SwiftUI

struct RecommendCoordinateByStandardItemView: View {
    @State private var partnerViewModel = PartnerViewModel()
    @State private var isInsightExpanded = false
    @Environment(\.dismiss) var dismiss

    let results: [CoordinateRecommendResult]
    let selectedItems: [StandardItem]
    let onComplete: (() -> Void)?

    init(
        results: [CoordinateRecommendResult],
        selectedItems: [StandardItem],
        onComplete: (() -> Void)? = nil
    ) {
        self.results = results
        self.selectedItems = selectedItems
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    // Top Section: Fashion Type + Insight (PartnerView風)
                    if let insight = partnerViewModel.userInsight {
                        topSection(insight: insight)
                    }

                    // Title
                    Text("選択したアイテムからコーデ提案")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    // Recommendations for each item
                    VStack(spacing: 40) {
                        ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                            if let coordinates = result.recommend_coordinates, !coordinates.isEmpty {
                                itemRecommendationSection(
                                    item: selectedItems[safe: index],
                                    result: result,
                                    coordinates: coordinates
                                )
                            }
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onComplete != nil)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("コーデ提案")
                    .font(.system(size: 18, weight: .semibold))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if let onComplete = onComplete {
                    // オンボーディングモード: 「次へ」ボタン
                    Button("次へ") {
                        onComplete()
                    }
                    .font(.system(size: 16, weight: .semibold))
                } else {
                    // 通常モード: 「閉じる」ボタン
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await partnerViewModel.fetchUserInsight()
        }
    }

    // MARK: - Top Section (PartnerView風)

    @ViewBuilder
    private func topSection(insight: UserInsightResponse) -> some View {
        if let fashionType = insight.fashion_type {
            HStack(alignment: .top, spacing: 16) {
                // 左側: 画像とファッションタイプ
                VStack(spacing: 12) {
                    Image(getFashionTypeImageName(fashionType.type_name))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

                    VStack(spacing: 4) {
                        Text(fashionType.type_code)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)

                        Text(fashionType.type_name)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 110)

                // 右側: インサイト
                VStack(alignment: .leading, spacing: 12) {
                    Text("インサイト")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)

                    if insight.insight.count > 80 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isInsightExpanded ? .init(insight.insight) : .init(String(insight.insight.prefix(80))) + "...")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.black)
                                .lineSpacing(4)

                            Button(action: {
                                withAnimation {
                                    isInsightExpanded.toggle()
                                }
                            }) {
                                Text(isInsightExpanded ? "閉じる" : "もっとみる")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        Text(.init(insight.insight))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.black)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
        } else {
            // ファッションタイプがない場合はインサイトのみ
            insightOnlySection(insight: insight.insight)
        }
    }

    private func insightOnlySection(insight: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("インサイト")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            Text(.init(insight))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.black)
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Item Recommendation Section

    private func itemRecommendationSection(
        item: StandardItem?,
        result: CoordinateRecommendResult,
        coordinates: [CoordinateRecommend]
    ) -> some View {
        VStack(spacing: 12) {
            // アイテム情報ヘッダー
            HStack(spacing: 12) {
                if let item = item {
                    CachedAsyncImage(url: URL(string: item.storage_url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.15)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.input_type)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)

                    HStack(spacing: 4) {
                        Text(result.category)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)

                        Text("•")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)

                        Text(result.text)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)

            // 横スクロールコーデ一覧 (RecentCoordinates風)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Spacer().frame(width: 12)

                    ForEach(Array(coordinates.enumerated()), id: \.offset) { index, coordinate in
                        CoordinateCard(coordinate: coordinate)
                    }

                    Spacer().frame(width: 12)
                }
            }
        }
    }

    // MARK: - Coordinate Card

    private func CoordinateCard(coordinate: CoordinateRecommend) -> some View {
        VStack(spacing: 8) {
            // コーデ画像
            ZStack {
                if coordinate.coordinate_image_path.hasPrefix("http") {
                    CachedAsyncImage(url: URL(string: coordinate.coordinate_image_path)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.15)
                    }
                } else {
                    FirebaseStorageImage(path: coordinate.coordinate_image_path)
                }
            }
            .frame(width: 140, height: 187)  // 3:4 ratio
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .clipped()
        }
    }

    // MARK: - Helpers

    private func getFashionTypeImageName(_ typeName: String) -> String {
        if UIImage(named: typeName) != nil {
            return typeName
        } else {
            return "アヴァンギャルド・スター"
        }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        RecommendCoordinateByStandardItemView(
            results: [],
            selectedItems: []
        )
    }
}
