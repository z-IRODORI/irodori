//
//  FashionTypeResultView.swift
//  irodori
//
//  Created by Claude on 2026/03/09.
//

import SwiftUI
import UIKit

struct FashionTypeResultView: View {
    @Binding var path: [ViewType]
    let result: FashionTypeResponse
    var onComplete: (() -> Void)? = nil

    @State private var showConfetti = false
    @State private var selectedScoreDetail: ScoreDetail?

    // 画像名を取得（存在しない場合はデフォルト画像）
    private var imageName: String {
        if UIImage(named: result.type_name) != nil {
            return result.type_name
        } else {
            return "アヴァンギャルド・スター"
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 32) {
                    // ヘッダー
                    VStack(spacing: 16) {
                        Text("診断結果")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)

                        // ファッションタイプ画像
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

                        // タイプコード
                        Text(result.type_code)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(16)

                        // タイプ名
                        Text(result.type_name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // スコア表示
                    VStack(spacing: 24) {
                        Text("あなたの特性")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)

                        VStack(spacing: 16) {
                            ScoreRow(
                                title: "流行感度",
                                score: result.trend_score,
                                color: .purple,
                                onInfoTapped: {
                                    selectedScoreDetail = ScoreDetail(
                                        title: "流行感度",
                                        score: result.trend_score,
                                        description: "SNSや雑誌、街のディスプレイで「今年の流行」をチェックするのが楽しい！季節の変わり目に「今年はどんな色が流行るんだろう？」とワクワクする。そんなトレンドへの感度を示すスコアです。",
                                        highScoreText: "高スコア: 流行に敏感で、最新のトレンドを誰よりも早くキャッチ。新しい刺激や変化が大好きなあなたは、常に新鮮なスタイルで周りを楽しませます。",
                                        lowScoreText: "低スコア: 流行に左右されない自分だけの定番スタイルを大切に。10年前の服も今でも自然に着こなせる、変わらない良さを知っているあなたです。"
                                    )
                                }
                            )
                            ScoreRow(
                                title: "自己起点",
                                score: result.self_score,
                                color: .blue,
                                onInfoTapped: {
                                    selectedScoreDetail = ScoreDetail(
                                        title: "自己起点",
                                        score: result.self_score,
                                        description: "服を選ぶとき、周囲の目よりも「自分が今日、どんな気分でいたいか」を優先する。雨の日でも大好きな明るい色の服を着て、自分のテンションを上げる。そんな自分の内面を大切にする姿勢を示すスコアです。",
                                        highScoreText: "高スコア: 「なりたい自分」や「理想のイメージ」を服で表現するのが得意。自分の好きなものを着て個性を輝かせるあなたは、誰にも真似できない魅力を持っています。",
                                        lowScoreText: "低スコア: 自分の気分だけでなく、周囲の意見や状況も大切に。バランス感覚に優れたあなたは、場に応じた柔軟な対応ができます。"
                                    )
                                }
                            )
                            ScoreRow(
                                title: "社会起点",
                                score: result.social_score,
                                color: .green,
                                onInfoTapped: {
                                    selectedScoreDetail = ScoreDetail(
                                        title: "社会起点",
                                        score: result.social_score,
                                        description: "誰かと会うとき、その相手が「自分にどんな印象を抱くか」をまず考える。高級レストランや親戚の集まりで「浮いていないこと」を確認して、初めて安心して楽しめる。そんなTPOや調和への意識を示すスコアです。",
                                        highScoreText: "高スコア: 場や相手に応じた適切な服装選びが得意。「この服なら失礼がないか」「清潔感があって安心してもらえるか」を自然と考えられるあなたは、周りへの配慮が素晴らしいです。",
                                        lowScoreText: "低スコア: TPOよりも自分らしさを大切に。場面に縛られず、どんな時も自分のスタイルを貫く強さを持っています。"
                                    )
                                }
                            )
                            ScoreRow(
                                title: "機能性",
                                score: result.function_score,
                                color: .orange,
                                onInfoTapped: {
                                    selectedScoreDetail = ScoreDetail(
                                        title: "機能性",
                                        score: result.function_score,
                                        description: "「結局、一日中ストレスなく動ける『着心地の良さ』が、自分にとっての正解だ」と感じるか。デザインがいくら良くても、素材がチクチクしたり動きにくい服は着ない。そんな快適さへのこだわりを示すスコアです。",
                                        highScoreText: "高スコア: 身体的快適さ・利便性を最優先。動きやすさやストレスフリーな着心地を求めるあなたは、一日を快適に過ごすための賢い選択ができます。",
                                        lowScoreText: "低スコア: 多少の不便さよりも見た目の美しさを優先。「このヒールを履くと足が綺麗に見えるから、多少の痛みは我慢！」というシルエット重視のあなたです。"
                                    )
                                }
                            )
                            ScoreRow(
                                title: "経済性",
                                score: result.economy_score,
                                color: .pink,
                                onInfoTapped: {
                                    selectedScoreDetail = ScoreDetail(
                                        title: "経済性",
                                        score: result.economy_score,
                                        description: "服を買うとき、まず値札を見て「この価格なら納得できるか（コスパ）」を吟味する。同じようなデザインなら「1円でも安い方」や「セールでどれだけお得か」を重視する。そんな経済的合理性と買い物上手さを示すスコアです。",
                                        highScoreText: "高スコア: 価格と品質のバランスを見極める買い物上手。コスパや得感を大切にするあなたは、限られた予算で最大の満足を得る賢さを持っています。",
                                        lowScoreText: "低スコア: 高価でも素材の背景やブランドの哲学に共感すれば投資する。「一生モノ」という言葉に弱く、数年後に味が出る良い素材のものを大切にするあなたです。"
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    // 完了ボタン
                    Button(action: {
                        if let onComplete = onComplete {
                            // onCompleteが設定されている場合（オンボーディングフロー）
                            onComplete()
                        } else {
                            // onCompleteがない場合（通常フロー）
                            // 診断画面と結果画面の両方を削除して元の画面に戻る
                            if path.count >= 2 {
                                path.removeLast(2)
                            } else {
                                path.removeAll()
                            }
                        }
                    }) {
                        Text(onComplete != nil ? "次へ" : "完了")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(25)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.white)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if let onComplete = onComplete {
                            onComplete()
                        } else {
                            if path.count >= 2 {
                                path.removeLast(2)
                            } else {
                                path.removeAll()
                            }
                        }
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
            }
            .onAppear {
                triggerCelebration()
            }
            .sheet(item: $selectedScoreDetail) { detail in
                ScoreDetailView(detail: detail)
            }

            // 花吹雪のオーバーレイ
            if showConfetti {
                ConfettiView()
            }
        }
    }

    private func triggerCelebration() {
        // Hapticフィードバック（1.5秒間小刻みな連続振動で達成感を演出）
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()

        // 1.5秒間、0.05秒間隔で小刻みに連続振動
        for i in 0..<30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                generator.impactOccurred()
            }
        }

        // 花吹雪を表示
        showConfetti = true
    }
}
