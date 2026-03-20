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
    @State private var selectedScoreDetail: ScoreDetail?

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerNavigationBar

            ZStack {
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
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
        .sheet(item: $selectedScoreDetail) { detail in
            ScoreDetailView(detail: detail)
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
                Text("相棒からあなたへ")
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
            Text("相棒からあなたへ")
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
                ScoreRow(
                    title: "流行感度",
                    score: fashionType.scores.trend_score,
                    color: .purple,
                    onInfoTapped: {
                        selectedScoreDetail = ScoreDetail(
                            title: "流行感度",
                            score: fashionType.scores.trend_score,
                            description: "SNSや雑誌、街のディスプレイで「今年の流行」をチェックするのが楽しい！季節の変わり目に「今年はどんな色が流行るんだろう？」とワクワクする。そんなトレンドへの感度を示すスコアです。",
                            highScoreText: "高スコア: 流行に敏感で、最新のトレンドを誰よりも早くキャッチ。新しい刺激や変化が大好きなあなたは、常に新鮮なスタイルで周りを楽しませます。",
                            lowScoreText: "低スコア: 流行に左右されない自分だけの定番スタイルを大切に。10年前の服も今でも自然に着こなせる、変わらない良さを知っているあなたです。"
                        )
                    }
                )
                ScoreRow(
                    title: "自己起点",
                    score: fashionType.scores.self_score,
                    color: .blue,
                    onInfoTapped: {
                        selectedScoreDetail = ScoreDetail(
                            title: "自己起点",
                            score: fashionType.scores.self_score,
                            description: "服を選ぶとき、周囲の目よりも「自分が今日、どんな気分でいたいか」を優先する。雨の日でも大好きな明るい色の服を着て、自分のテンションを上げる。そんな自分の内面を大切にする姿勢を示すスコアです。",
                            highScoreText: "高スコア: 「なりたい自分」や「理想のイメージ」を服で表現するのが得意。自分の好きなものを着て個性を輝かせるあなたは、誰にも真似できない魅力を持っています。",
                            lowScoreText: "低スコア: 自分の気分だけでなく、周囲の意見や状況も大切に。バランス感覚に優れたあなたは、場に応じた柔軟な対応ができます。"
                        )
                    }
                )
                ScoreRow(
                    title: "社会起点",
                    score: fashionType.scores.social_score,
                    color: .green,
                    onInfoTapped: {
                        selectedScoreDetail = ScoreDetail(
                            title: "社会起点",
                            score: fashionType.scores.social_score,
                            description: "誰かと会うとき、その相手が「自分にどんな印象を抱くか」をまず考える。高級レストランや親戚の集まりで「浮いていないこと」を確認して、初めて安心して楽しめる。そんなTPOや調和への意識を示すスコアです。",
                            highScoreText: "高スコア: 場や相手に応じた適切な服装選びが得意。「この服なら失礼がないか」「清潔感があって安心してもらえるか」を自然と考えられるあなたは、周りへの配慮が素晴らしいです。",
                            lowScoreText: "低スコア: TPOよりも自分らしさを大切に。場面に縛られず、どんな時も自分のスタイルを貫く強さを持っています。"
                        )
                    }
                )
                ScoreRow(
                    title: "機能性",
                    score: fashionType.scores.function_score,
                    color: .orange,
                    onInfoTapped: {
                        selectedScoreDetail = ScoreDetail(
                            title: "機能性",
                            score: fashionType.scores.function_score,
                            description: "「結局、一日中ストレスなく動ける『着心地の良さ』が、自分にとっての正解だ」と感じるか。デザインがいくら良くても、素材がチクチクしたり動きにくい服は着ない。そんな快適さへのこだわりを示すスコアです。",
                            highScoreText: "高スコア: 身体的快適さ・利便性を最優先。動きやすさやストレスフリーな着心地を求めるあなたは、一日を快適に過ごすための賢い選択ができます。",
                            lowScoreText: "低スコア: 多少の不便さよりも見た目の美しさを優先。「このヒールを履くと足が綺麗に見えるから、多少の痛みは我慢！」というシルエット重視のあなたです。"
                        )
                    }
                )
                ScoreRow(
                    title: "経済性",
                    score: fashionType.scores.economy_score,
                    color: .pink,
                    onInfoTapped: {
                        selectedScoreDetail = ScoreDetail(
                            title: "経済性",
                            score: fashionType.scores.economy_score,
                            description: "服を買うとき、まず値札を見て「この価格なら納得できるか（コスパ）」を吟味する。同じようなデザインなら「1円でも安い方」や「セールでどれだけお得か」を重視する。そんな経済的合理性と買い物上手さを示すスコアです。",
                            highScoreText: "高スコア: 価格と品質のバランスを見極める買い物上手。コスパや得感を大切にするあなたは、限られた予算で最大の満足を得る賢さを持っています。",
                            lowScoreText: "低スコア: 高価でも素材の背景やブランドの哲学に共感すれば投資する。「一生モノ」という言葉に弱く、数年後に味が出る良い素材のものを大切にするあなたです。"
                        )
                    }
                )
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
