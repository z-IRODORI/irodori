//
//  FashionTypeResultView.swift
//  irodori
//
//  Created by Claude on 2026/03/09.
//

import SwiftUI

struct FashionTypeResultView: View {
    @Binding var path: [ViewType]
    let result: FashionTypeResponse

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // ヘッダー
                VStack(spacing: 16) {
                    Text("診断結果")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)

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
                    // 診断画面と結果画面の両方を削除して元の画面に戻る
                    if path.count >= 2 {
                        path.removeLast(2)
                    } else {
                        path.removeAll()
                    }
                }) {
                    Text("完了")
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
                    if path.count >= 2 {
                        path.removeLast(2)
                    } else {
                        path.removeAll()
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                }
            }
        }
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
