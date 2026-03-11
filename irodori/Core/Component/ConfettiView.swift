//
//  ConfettiView.swift
//  irodori
//
//  Created by Claude on 2026/03/09.
//

import SwiftUI

// MARK: - Step 1: データモデル定義

struct ConfettiItem: Identifiable {
    let id: UUID
    var x: CGFloat          // X座標
    var y: CGFloat          // Y座標
    let color: Color        // 色
    let size: CGFloat       // サイズ
    var rotation: Angle     // 回転角度
    var opacity: Double     // 透明度
}

// MARK: - Step 2: 紙吹雪のビジュアル（四角形）

struct ConfettiPiece: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .cornerRadius(2)
    }
}

// MARK: - Step 3: メインビュー

struct ConfettiView: View {
    @State private var confettiItems: [ConfettiItem] = []
    let colors: [Color] = [.pink, .blue, .purple, .yellow, .green, .orange, .red]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiItems) { item in
                    ConfettiPiece(color: item.color)
                        .frame(width: item.size, height: item.size)
                        .offset(x: item.x, y: item.y)
                        .rotationEffect(item.rotation)
                        .opacity(item.opacity)
                }
            }
            .onAppear {
                createConfetti(in: geometry.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Step 4: 位置計算ヘルパー関数

    /// 開始位置を計算（画面下中央）
    private func calculateStartPosition(screenSize: CGSize) -> CGPoint {
        let centerX = screenSize.width / 2
        let randomOffsetX = CGFloat.random(in: -30...30)  // 中央から少しずらす
        let startY = screenSize.height  // 画面下端

        return CGPoint(x: centerX + randomOffsetX, y: startY)
    }

    /// 終了位置を計算（上の左右に広がる）
    private func calculateEndPosition(screenSize: CGSize, startX: CGFloat) -> CGPoint {
        // 画面上部のランダムな位置
        let endY = CGFloat.random(in: -200...screenSize.height * 0.3)

        // 左右に広がる: 画面全体の幅にランダムに分散
        let endX = CGFloat.random(in: 0...screenSize.width)

        return CGPoint(x: endX, y: endY)
    }

    // MARK: - Step 5: 紙吹雪生成メイン関数

    private func createConfetti(in size: CGSize) {
        let confettiCount = 100  // 紙吹雪の数

        for i in 0..<confettiCount {
            let delay = Double(i) * 0.01  // 順次出現（0.01秒ごと）

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 開始位置を計算
                let startPosition = calculateStartPosition(screenSize: size)

                // 紙吹雪アイテムを作成
                let item = ConfettiItem(
                    id: UUID(),
                    x: startPosition.x,
                    y: startPosition.y,
                    color: colors.randomElement() ?? .pink,
                    size: CGFloat.random(in: 8...16),
                    rotation: .degrees(Double.random(in: 0...360)),
                    opacity: 1.0
                )

                confettiItems.append(item)

                // MARK: - Step 6: 位置移動アニメーション

                // 終了位置を計算
                let endPosition = calculateEndPosition(screenSize: size, startX: startPosition.x)

                // 画面下部に0.3秒間滞在してから上に移動
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // スプリングアニメーションで移動
                    withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                        if let index = confettiItems.firstIndex(where: { $0.id == item.id }) {
                            confettiItems[index].x = endPosition.x
                            confettiItems[index].y = endPosition.y
                        }
                    }
                }

                // MARK: - Step 7: 回転アニメーション

                // 紙吹雪が回転しながら落ちる
                let rotationDuration = Double.random(in: 1.0...2.0)
                withAnimation(.linear(duration: rotationDuration).repeatForever(autoreverses: false)) {
                    if let index = confettiItems.firstIndex(where: { $0.id == item.id }) {
                        confettiItems[index].rotation = .degrees(360)
                    }
                }

                // MARK: - Step 8: フェードアウトと削除

                // 2.5秒後にフェードアウト開始（滞在時間を考慮）
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        if let index = confettiItems.firstIndex(where: { $0.id == item.id }) {
                            confettiItems[index].opacity = 0
                        }
                    }

                    // フェードアウト完了後に削除
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        confettiItems.removeAll { $0.id == item.id }
                    }
                }
            }
        }
    }
}
