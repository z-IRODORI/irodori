//
//  PartnerView.swift
//  irodori
//
//  Created by Claude on 2026/03/12.
//

import SwiftUI

struct PartnerView: View {
    @State var viewModel = PartnerViewModel()
    @State private var isInsightExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerNavigationBar

            ZStack {
                if viewModel.isLoading {
                    ProgressView("インサイトを読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let insight = viewModel.userInsight {
                    ScrollView {
                        VStack(spacing: 32) {
                            // 上部：左に画像・ファッションタイプ、右にインサイト
                            if let fashionType = insight.fashion_type {
                                topSection(fashionType: fashionType, insight: insight.insight)
                            } else {
                                // ファッションタイプがない場合はインサイトのみ表示
                                insightSection(insight: insight.insight)
                            }

                            // ファッションタイプのスコア情報
                            if let fashionType = insight.fashion_type {
                                scoreSection(fashionType: fashionType)
                            }

                            // 動物占い情報
                            if let animalFortune = insight.animal_fortune {
                                animalFortuneSection(animalFortune: animalFortune)
                            }
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 100)
                    }
                    .background(Color.white)
                } else {
                    emptyStateView
                }
            }
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラー")
        }
        .task {
            await viewModel.fetchUserInsight()
        }
    }

    // MARK: - Header

    private var headerNavigationBar: some View {
        HStack {
            Spacer()

            Text("相棒")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Sections

    // 上部セクション：左に画像・ファッションタイプ、右にインサイト
    private func topSection(fashionType: UserInsightResponse.FashionTypeInfo, insight: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // 左側：画像とファッションタイプ
            VStack(spacing: 12) {
                Image(getFashionTypeImageName(fashionType.type_name))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

                VStack(spacing: 4) {
                    // アルファベット（type_code）を大きく表示
                    Text(fashionType.type_code)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    // ファッションタイプ名（type_name）を小さく表示
                    Text(fashionType.type_name)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 110)

            // 右側：インサイト
            VStack(alignment: .leading, spacing: 12) {
                Text("インサイト")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)

                if insight.count > 100 {
                    VStack(alignment: .leading, spacing: 8) {
                        if isInsightExpanded {
                            Text(.init(insight))
                                .font(.system(size: 13))
                                .foregroundColor(.black)
                                .lineSpacing(4)
                        } else {
                            Text(.init(String(insight.prefix(100)) + "..."))
                                .font(.system(size: 13))
                                .foregroundColor(.black)
                                .lineSpacing(4)
                        }

                        Button(action: {
                            withAnimation {
                                isInsightExpanded.toggle()
                            }
                        }) {
                            Text(isInsightExpanded ? "閉じる" : "もっとみる")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    Text(.init(insight))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.black)
                        .lineSpacing(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
    }

    private func insightSection(insight: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("インサイト")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)

            // インサイト本文（100文字以上の場合は折りたたみ可能）
            if insight.count > 100 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isInsightExpanded ? .init(insight) : .init(String(insight.prefix(100))) + "...")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.black)
                        .lineSpacing(4)

                    Button(action: {
                        withAnimation {
                            isInsightExpanded.toggle()
                        }
                    }) {
                        Text(isInsightExpanded ? "閉じる" : "もっとみる")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Text(.init(insight))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 24)
    }

    // スコアセクション
    private func scoreSection(fashionType: UserInsightResponse.FashionTypeInfo) -> some View {
        VStack(spacing: 24) {
            Text("ファッションタイプスコア")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                ScoreRow(title: "流行感度", score: fashionType.scores.trend_score, color: .purple)
                ScoreRow(title: "自己起点", score: fashionType.scores.self_score, color: .blue)
                ScoreRow(title: "社会起点", score: fashionType.scores.social_score, color: .green)
                ScoreRow(title: "機能性", score: fashionType.scores.function_score, color: .orange)
                ScoreRow(title: "経済性", score: fashionType.scores.economy_score, color: .pink)
            }
        }
        .padding(.horizontal, 24)
    }

    // 画像名を取得（存在しない場合はデフォルト画像）
    private func getFashionTypeImageName(_ typeName: String) -> String {
        if UIImage(named: typeName) != nil {
            return typeName
        } else {
            return "アヴァンギャルド・スター"
        }
    }

    private func animalFortuneSection(animalFortune: UserInsightResponse.AnimalFortuneInfo) -> some View {
        VStack(spacing: 24) {
            Text("動物占い")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)

            // 動物名
            Text(animalFortune.animal_name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)

            // 基本性格
            if let basePersonality = animalFortune.base_personality {
                InfoRow(title: "基本性格", content: basePersonality)
            }

            // 人生傾向
            if let lifeTendency = animalFortune.life_tendency {
                InfoRow(title: "人生傾向", content: lifeTendency)
            }
        }
        .padding(.horizontal, 24)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("データがありません")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)

            Text("ファッションタイプ診断または動物占いを実施してください。")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Components

struct InfoRow: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)

            Text(content)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.black)
                .lineSpacing(4)
        }
    }
}
