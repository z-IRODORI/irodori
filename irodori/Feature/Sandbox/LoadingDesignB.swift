//
//  LoadingDesignB.swift
//  irodori - Sandbox
//
//  案B: 相棒が写真を探索.
//  相棒アイコンが虫眼鏡を持って撮影画像の上を移動し、
//  トップス / ボトムスを見つけるたびに立ち止まってコメントする。
//

import SwiftUI

struct LoadingDesignB: View {
    @State private var phase: LoadingDemoPhase = .scanning
    @State private var bob = false        // 相棒のふわふわ上下
    @State private var pulse = false      // 注目リングのパルス

    var body: some View {
        VStack(spacing: 20) {
            LoadingDemoHeader(
                title: "レビュー作成中...",
                subtitle: "相棒がコーデをチェックしています"
            )
            .padding(.top, 24)

            photoWithBuddy
                .padding(.horizontal, 36)

            LoadingDemoStepBar(phase: phase)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .loadingDemoPhaseDriver($phase)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                bob = true
            }
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    // MARK: - フェーズごとの相棒の立ち位置とセリフ (正規化座標)

    private var buddyPoint: CGPoint {
        switch phase {
        case .scanning: CGPoint(x: 0.50, y: 0.13)
        case .topsDetected: CGPoint(x: 0.80, y: 0.31)
        case .bottomsDetected: CGPoint(x: 0.80, y: 0.62)
        case .analyzing: CGPoint(x: 0.50, y: 0.85)
        }
    }

    private var comment: String {
        switch phase {
        case .scanning: "全体のバランスを見てるよ〜"
        case .topsDetected: "白Tのロゴがいいアクセント！"
        case .bottomsDetected: "黒パンツで引き締まってる◎"
        case .analyzing: "うんうん、レビューをまとめるね！"
        }
    }

    /// 注目している領域の中心 (検出フェーズのみ)
    private var focusPoint: CGPoint? {
        switch phase {
        case .topsDetected:
            CGPoint(x: LoadingSandbox.topsRect.midX, y: LoadingSandbox.topsRect.midY)
        case .bottomsDetected:
            CGPoint(x: LoadingSandbox.bottomsRect.midX, y: LoadingSandbox.bottomsRect.midY)
        default: nil
        }
    }

    // MARK: - 写真 + 相棒オーバーレイ

    private var photoWithBuddy: some View {
        Image(uiImage: LoadingSandbox.sampleImage)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        if let focusPoint {
                            focusRing
                                .position(x: focusPoint.x * size.width, y: focusPoint.y * size.height)
                        }
                        buddy
                            .position(
                                x: buddyPoint.x * size.width,
                                y: buddyPoint.y * size.height + (bob ? -5 : 5)
                            )
                        LoadingDemoBubble(text: comment)
                            .id(phase)   // フェーズ切替でポップし直す
                            .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                            .position(
                                x: min(max(buddyPoint.x * size.width, 105), size.width - 105),
                                y: max(buddyPoint.y * size.height - 72, 34)
                            )
                    }
                }
            }
    }

    private var buddy: some View {
        PartnerIconImage(size: 54)
            .overlay {
                Circle().stroke(.white, lineWidth: 2.5)
            }
            .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(LoadingSandbox.brandGradient)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(bob ? -12 : 8))
                    .offset(x: 6, y: 4)
            }
    }

    private var focusRing: some View {
        Circle()
            .stroke(LoadingSandbox.brandPink, lineWidth: 2.5)
            .frame(width: 74, height: 74)
            .scaleEffect(pulse ? 1.35 : 0.7)
            .opacity(pulse ? 0 : 0.9)
            .allowsHitTesting(false)
    }
}

#Preview("B: 相棒探索") {
    LoadingDesignB()
}
