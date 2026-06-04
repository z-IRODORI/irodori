//
//  PartnerDesignC.swift
//  irodori - Sandbox
//
//  案C: トレカ + レーダーチャート.
//  ファッションタイプを「キャラ図鑑のカード」として演出. タップで裏返って詳細.
//  スコアは 5角形レーダーチャートで一目把握.
//

import SwiftUI

struct PartnerDesignC: View {
    let insight: UserInsightResponse
    @State private var isFlipped = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if let ft = insight.fashion_type {
                    tradingCard(ft)
                        .padding(.horizontal, 24)
                        .frame(height: 460)

                    radarSection(ft)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(
            LinearGradient(
                colors: [Color.pink.opacity(0.06), Color.white],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
    }

    private var header: some View {
        Text("相棒")
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.white)
    }

    // MARK: - Trading Card

    @ViewBuilder
    private func tradingCard(_ ft: UserInsightResponse.FashionTypeInfo) -> some View {
        ZStack {
            if isFlipped {
                cardBack(ft)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                cardFront(ft)
            }
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: isFlipped)
        .onTapGesture {
            Haptic.impact(.soft)
            isFlipped.toggle()
        }
    }

    private func cardFront(_ ft: UserInsightResponse.FashionTypeInfo) -> some View {
        VStack(spacing: 0) {
            // 上部カラーバー
            HStack {
                Text(ft.type_code)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Tap to flip")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.pink)

            // メインビジュアル
            Image(PartnerSandboxImage.name(for: ft.type_name))
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()

            // 下部情報
            VStack(alignment: .leading, spacing: 8) {
                Text(ft.type_name)
                    .font(.system(size: 20, weight: .bold))
                Text(ft.core_stance)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    PartnerSandboxChip(text: "Group: \(ft.group)")
                    PartnerSandboxChip(text: ft.type_code)
                }
                .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.pink.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    private func cardBack(_ ft: UserInsightResponse.FashionTypeInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("相棒からのひとこと")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Tap to flip")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.pink)

            ScrollView {
                Text(insight.insight)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }

            Spacer(minLength: 0)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.pink.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    // MARK: - Radar

    private func radarSection(_ ft: UserInsightResponse.FashionTypeInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ステータス")
                .font(.system(size: 16, weight: .semibold))
            PartnerSandboxRadarChart(
                values: [
                    ft.scores.trend_score,
                    ft.scores.self_score,
                    ft.scores.social_score,
                    ft.scores.function_score,
                    ft.scores.economy_score
                ],
                labels: ["流行", "自己", "社会", "機能", "経済"]
            )
            .frame(height: 240)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

#Preview("案C: トレカ") {
    PartnerDesignC(insight: PartnerSandbox.mockInsight())
}
