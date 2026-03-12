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
                            ScoreRow(title: "流行感度", score: result.trend_score, color: .purple)
                            ScoreRow(title: "自己起点", score: result.self_score, color: .blue)
                            ScoreRow(title: "社会起点", score: result.social_score, color: .green)
                            ScoreRow(title: "機能性", score: result.function_score, color: .orange)
                            ScoreRow(title: "経済性", score: result.economy_score, color: .pink)
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

// MARK: - Score Row Component

struct ScoreRow: View {
    let title: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)

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
