//
//  PartnerDesignA.swift
//  irodori - Sandbox
//
//  案A: 吹き出し型. 既存 SpeechBubbleView を流用して相棒キャラが横から話しかける構図.
//  insight を意味ブロックで 2-3 の吹き出しに分割.
//

import SwiftUI

struct PartnerDesignA: View {
    let insight: UserInsightResponse

    private var bubbles: [String] {
        // 単純に「。」 「！」 などで分割し、2-3 個の吹き出しに整形
        let text = insight.insight
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text
            .components(separatedBy: CharacterSet(charactersIn: "。！"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0 + (text.contains($0 + "！") ? "！" : "。") }
        if parts.isEmpty { return [text] }
        return Array(parts.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                // 相棒キャラ画像 + 吹き出し群
                if let ft = insight.fashion_type {
                    HStack(alignment: .top, spacing: 0) {
                        Image(PartnerSandboxImage.name(for: ft.type_name))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(bubbles.enumerated()), id: \.offset) { _, text in
                                SpeechBubbleView(text: text)
                                    .frame(height: 90)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    typeFooter(ft)
                        .padding(.horizontal, 24)
                }

                scoreList

                Spacer(minLength: 24)
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.gray.opacity(0.06))
    }

    private var header: some View {
        Text("相棒")
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.white)
    }

    private func typeFooter(_ ft: UserInsightResponse.FashionTypeInfo) -> some View {
        HStack(spacing: 8) {
            Text(ft.type_code)
                .font(.system(size: 13, weight: .bold))
            Text("·")
                .foregroundStyle(.secondary)
            Text(ft.type_name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button("詳細") { }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black)
                .clipShape(Capsule())
        }
    }

    private var scoreList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ファッションタイプスコア")
                .font(.system(size: 16, weight: .semibold))
            if let s = insight.fashion_type?.scores {
                scoreRow("流行感度", s.trend_score)
                scoreRow("自己起点", s.self_score)
                scoreRow("社会起点", s.social_score)
                scoreRow("機能性", s.function_score)
                scoreRow("経済性", s.economy_score)
            }
        }
        .padding(.horizontal, 24)
    }

    private func scoreRow(_ title: String, _ value: Double) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.12))
                    Capsule()
                        .fill(Color.pink)
                        .frame(width: geo.size.width * CGFloat(min(value, 5) / 5))
                }
            }
            .frame(height: 8)
            Text(String(format: "%.1f", value))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

#Preview("案A: 吹き出し") {
    PartnerDesignA(insight: PartnerSandbox.mockInsight())
}
