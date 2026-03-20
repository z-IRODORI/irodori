//
//  ScoreComponents.swift
//  irodori
//
//  Created by Claude on 2026/03/20.
//

import SwiftUI

// MARK: - Score Detail Model

struct ScoreDetail: Identifiable {
    let id = UUID()
    let title: String
    let score: Double
    let description: String
    let highScoreText: String
    let lowScoreText: String
}

// MARK: - Score Detail View

struct ScoreDetailView: View {
    let detail: ScoreDetail
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // スコア表示
                    VStack(spacing: 12) {
                        Text(detail.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)

                        Text(String(format: "%.1f / 5.0", detail.score))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    // 説明
                    VStack(alignment: .leading, spacing: 16) {
                        Text("このスコアについて")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)

                        Text(detail.description)
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .lineSpacing(4)
                    }

                    Divider()

                    // 高スコア・低スコアの説明
                    VStack(alignment: .leading, spacing: 16) {
                        ScoreExplanationRow(
                            icon: "arrow.up.circle.fill",
                            iconColor: .green,
                            text: detail.highScoreText
                        )

                        ScoreExplanationRow(
                            icon: "arrow.down.circle.fill",
                            iconColor: .orange,
                            text: detail.lowScoreText
                        )
                    }
                }
                .padding(24)
            }
            .navigationTitle("スコア詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

struct ScoreExplanationRow: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.black)
                .lineSpacing(4)
        }
    }
}

// MARK: - Score Row Component

struct ScoreRow: View {
    let title: String
    let score: Double
    let color: Color
    var onInfoTapped: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)

                if onInfoTapped != nil {
                    Button(action: {
                        onInfoTapped?()
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Text(String(format: "%.1f", score))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }

            // プログレスバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (score / 5.0), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}
