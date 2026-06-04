//
//  PartnerDesignsShared.swift
//  irodori - Sandbox
//
//  「相棒」画面のポップ化候補で共有する Mock と小物.
//

import SwiftUI

// MARK: - モック (現状の UserInsightResponse.mock より少し長文に)

enum PartnerSandbox {
    static func mockInsight() -> UserInsightResponse {
        UserInsightResponse(
            status: "success",
            user_id: "mock-user",
            insight_id: "mock-insight",
            fashion_type: .init(
                type_code: "T-P-A-Q",
                type_name: "トレンド・エディター",
                description: "流行を編集して、自分らしく落とし込むタイプ。",
                core_stance: "今っぽさと自分らしさのバランス重視。",
                group: "TP",
                group_color: "#FF6B6B",
                scores: .init(
                    trend_score: 4.2,
                    self_score: 4.0,
                    social_score: 3.1,
                    function_score: 2.4,
                    economy_score: 3.6
                )
            ),
            animal_fortune: nil,
            insight: """
            最近のあなたはモノトーン軸に、ベージュやくすみカラーで温度感を足すのが上手。
            シルエットはきれいめのまま、小物で遊ぶ余地を残しているのがエディターらしいバランス感。
            次は素材のコントラスト (例: コットン×レザー) に挑戦すると、もう一段「あなたの世界観」がはっきりするはず！
            """,
            generated_at: "2026-05-17T10:00:00.000000"
        )
    }
}

// MARK: - 共通 chip / accent

struct PartnerSandboxChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - レーダーチャート (案C で使う、シンプル実装)

struct PartnerSandboxRadarChart: View {
    /// 5 軸 (trend, self, social, function, economy) の値 (0-5 を想定)
    let values: [Double]
    let labels: [String]
    var maxValue: Double = 5

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - 24
            let n = values.count

            ZStack {
                // 背景の同心多角形 (4段階)
                ForEach(1...4, id: \.self) { step in
                    polygon(center: center, radius: radius * CGFloat(step) / 4, n: n)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                }
                // データポリゴン
                dataPolygon(center: center, radius: radius)
                    .fill(Color.pink.opacity(0.18))
                dataPolygon(center: center, radius: radius)
                    .stroke(Color.pink, lineWidth: 2)
                // 頂点ラベル
                ForEach(0..<n, id: \.self) { i in
                    let angle = angleFor(i)
                    let pt = pointOnCircle(center: center, radius: radius + 16, angle: angle)
                    Text(labels[i])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .position(pt)
                }
            }
        }
    }

    private func angleFor(_ i: Int) -> Double {
        let n = Double(values.count)
        return -.pi / 2 + (2 * .pi * Double(i) / n)
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }

    private func polygon(center: CGPoint, radius: CGFloat, n: Int) -> Path {
        Path { p in
            for i in 0..<n {
                let pt = pointOnCircle(center: center, radius: radius, angle: angleFor(i))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }

    private func dataPolygon(center: CGPoint, radius: CGFloat) -> Path {
        Path { p in
            for i in 0..<values.count {
                let r = radius * CGFloat(min(values[i], maxValue) / maxValue)
                let pt = pointOnCircle(center: center, radius: r, angle: angleFor(i))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
}

// MARK: - ファッションタイプ画像 (存在しなければ default)

enum PartnerSandboxImage {
    static func name(for typeName: String) -> String {
        UIImage(named: typeName) != nil ? typeName : "アヴァンギャルド・スター"
    }
}
