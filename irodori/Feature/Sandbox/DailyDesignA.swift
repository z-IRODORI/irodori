//
//  DailyDesignA.swift
//  irodori - Sandbox
//
//  案A: 3×3 グリッド主役 + 1枚目に「イチオシ」バッジのみ。
//       情報量を最小限にし、9件のビジュアルを最大限見せる構成。
//

import SwiftUI
import Kingfisher

struct DailyDesignA: View {
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
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(response.recommendations.enumerated()), id: \.element.id) { idx, item in
                Button { onTap(item) } label: {
                    ZStack(alignment: .topTrailing) {
                        SandboxCoordImage(source: item.image_url)
                            .scaledToFill()
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(10)
                        if idx == 0 {
                            SandboxIchioshiBadge().padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("案A: バッジのみ") {
    DailyDesignA(response: SandboxDaily.mockResponse())
}
