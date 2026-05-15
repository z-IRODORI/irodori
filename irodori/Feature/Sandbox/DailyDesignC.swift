//
//  DailyDesignC.swift
//  irodori - Sandbox
//
//  案C: 3×3 グリッド主役 + 各カード下に vibe/style ラベル。
//       9枚それぞれの特徴がひと目で分かり、選択時の判断材料が増える。
//

import SwiftUI
import Kingfisher

struct DailyDesignC: View {
    let response: DailyRecommendationResponse
    var onTap: (DailyRecommendationItem) -> Void = { _ in }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("明日のコーデ")
                    .font(.system(size: 20, weight: .bold))
                SandboxCompactWeatherBar(weather: response.weather, dateString: response.target_date)
                if let c = response.partner_comment, !c.isEmpty {
                    SandboxPartnerComment(text: c)
                }
                grid
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.gray.opacity(0.08))
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(response.recommendations.enumerated()), id: \.element.id) { idx, item in
                Button { onTap(item) } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            SandboxCoordImage(source: item.image_url)
                                .scaledToFill()
                                .frame(height: 140)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(10)
                            if idx == 0 {
                                SandboxIchioshiBadge().padding(6)
                            }
                        }
                        Text(caption(item))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func caption(_ item: DailyRecommendationItem) -> String {
        if !item.vibe.isEmpty { return item.vibe }
        if !item.style.isEmpty { return item.style }
        return ""
    }
}

#Preview("案C: キャプション付き") {
    DailyDesignC(response: SandboxDaily.mockResponse())
}
