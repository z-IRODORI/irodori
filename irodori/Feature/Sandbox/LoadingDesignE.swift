//
//  LoadingDesignE.swift
//  irodori - Sandbox
//
//  案E: コーデスロット.
//  トップス / ボトムスのリールが回転し、AI が何通りも組み合わせを
//  試しているメタファーで待たせる。ロック時にコメントと連動。
//

import SwiftUI

struct LoadingDesignE: View {
    @State private var topsIndex = 0
    @State private var bottomsIndex = 0
    @State private var isSpinning = true
    @State private var comboCount = 0
    @State private var lockedComment = ""

    private let topsReel = ["👕", "🧥", "👚", "🧣", "👔"]
    private let bottomsReel = ["👖", "🩳", "👗", "🧦", "👢"]
    private let comments = [
        "その組み合わせ、アリかも…！",
        "うーん、もう少し探してみるね",
        "色のバランスがいい感じ！",
        "これは君に似合いそう…！",
    ]

    var body: some View {
        VStack(spacing: 28) {
            LoadingDemoHeader(
                title: "AIがコーデを思案中...",
                subtitle: "何通りも組み合わせて、ベストな提案を探しています"
            )
            .padding(.top, 24)

            HStack(spacing: 16) {
                reel(title: "トップス", items: topsReel, index: topsIndex)
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.5))
                reel(title: "ボトムス", items: bottomsReel, index: bottomsIndex)
            }

            commentLabel

            VStack(spacing: 8) {
                Text("\(comboCount) 通り目を検討中…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray)
                    .contentTransition(.numericText())
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(LoadingSandbox.brandPink)
                            .frame(width: 6, height: 6)
                            .opacity(isSpinning ? 1 : 0.25)
                            .animation(
                                .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.18),
                                value: isSpinning
                            )
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .task { await runSlotLoop() }
    }

    // MARK: - リール

    private func reel(title: String, items: [String], index: Int) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
            VStack(spacing: 2) {
                Text(items[(index + items.count - 1) % items.count])
                    .font(.system(size: 26))
                    .opacity(0.18)
                Text(items[index])
                    .font(.system(size: 56))
                    .blur(radius: isSpinning ? 1.8 : 0)
                    .scaleEffect(isSpinning ? 0.96 : 1.06)
                Text(items[(index + 1) % items.count])
                    .font(.system(size: 26))
                    .opacity(0.18)
            }
            .frame(width: 116, height: 150)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSpinning ? Color.gray.opacity(0.15) : LoadingSandbox.brandPink,
                        lineWidth: isSpinning ? 1 : 2.5
                    )
            }
            .shadow(
                color: isSpinning ? .clear : LoadingSandbox.brandPink.opacity(0.35),
                radius: 10
            )
        }
    }

    private var commentLabel: some View {
        Group {
            if isSpinning {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("シャッフル中...")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.gray.opacity(0.6))
            } else {
                HStack(spacing: 8) {
                    PartnerIconImage(size: 28)
                    Text(lockedComment)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(LoadingSandbox.brandPink.opacity(0.10))
                .clipShape(Capsule())
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(height: 48)
    }

    // MARK: - スロット進行

    private func runSlotLoop() async {
        var commentIndex = 0
        while !Task.isCancelled {
            withAnimation(.easeIn(duration: 0.2)) { isSpinning = true }

            // 高速回転
            for _ in 0..<16 {
                advanceReels()
                try? await Task.sleep(for: .milliseconds(75))
                if Task.isCancelled { return }
            }
            // 減速
            for delay in [110, 150, 210, 290, 400] {
                advanceReels()
                try? await Task.sleep(for: .milliseconds(delay))
                if Task.isCancelled { return }
            }

            // ロック
            lockedComment = comments[commentIndex]
            commentIndex = (commentIndex + 1) % comments.count
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                isSpinning = false
            }
            Haptic.impact(.soft)

            try? await Task.sleep(for: .seconds(1.8))
        }
    }

    private func advanceReels() {
        topsIndex = (topsIndex + 1) % topsReel.count
        // ボトムスは 1 個ずらして回すと組み合わせが単調にならない
        if topsIndex % 2 == 0 {
            bottomsIndex = (bottomsIndex + 1) % bottomsReel.count
        } else {
            bottomsIndex = (bottomsIndex + 2) % bottomsReel.count
        }
        withAnimation(.linear(duration: 0.06)) {
            comboCount += 1
        }
    }
}

#Preview("E: コーデスロット") {
    LoadingDesignE()
}
