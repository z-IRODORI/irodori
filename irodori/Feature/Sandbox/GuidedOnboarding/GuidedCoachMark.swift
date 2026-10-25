//
//  GuidedCoachMark.swift
//  irodori - Sandbox
//
//  ツールチップ型オンボーディングの部品。
//  画面の部品に .coachAnchor(.recipes) を付けておくと、その位置を指して吹き出しを出せる。
//  - ツアー型: 画面を暗くして、指した部品だけをくり抜いて見せる (どこを押しても次へ)
//  - その場型: 暗くせず、吹き出しだけを部品のそばに出す (操作のじゃまをしない)
//

import SwiftUI

// MARK: - 指す先

enum CoachTarget: String, CaseIterable {
    case partner, recipes, feedback, growth, camera
}

struct CoachTip: Equatable {
    let target: CoachTarget
    let title: String
    let body: String

    static let partner = CoachTip(target: .partner, title: "相棒のひとこと",
                                  body: "タップすると相棒画面へ。覚えたことや、ふたりの記録が見られるよ")
    static let recipes = CoachTip(target: .recipes, title: "明日の3案",
                                  body: "気温と手持ちの服から組んだよ。気に入ったら「着る」、ピンとこなければ「ちょっと違う」を押してね")
    static let feedback = CoachTip(target: .feedback, title: "教えてくれてありがとう",
                                   body: "理由を選ぶと、次の3案から外して組み直すよ")
    static let growth = CoachTip(target: .growth, title: "服を教えてほしいな",
                                 body: "写真や定番アイテムで服を教えると、あなたの服だけで組める案が増えるよ")
    static let camera = CoachTip(target: .camera, title: "着た日はここから1枚",
                                 body: "全身を撮ると着回しのクセがわかるよ。ふたりの記録にも残るね")
}

// MARK: - 位置を集める

struct CoachAnchorKey: PreferenceKey {
    static var defaultValue: [CoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachTarget: Anchor<CGRect>], nextValue: () -> [CoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// この部品をツールチップで指せるようにする
    func coachAnchor(_ target: CoachTarget) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [target: $0] }
    }
}

// MARK: - 重ねる層

struct CoachMarkLayer: View {
    let anchors: [CoachTarget: Anchor<CGRect>]
    let tip: CoachTip?
    /// true: ツアー型 (暗くしてくり抜く) / false: その場型 (吹き出しだけ)
    let spotlight: Bool
    /// 「1 / 4」。その場型では nil
    var step: (index: Int, total: Int)? = nil
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            if let tip, let anchor = anchors[tip.target] {
                let rect = proxy[anchor].insetBy(dx: -6, dy: -6)
                ZStack {
                    if spotlight {
                        CoachSpotlight(hole: rect)
                            .contentShape(Rectangle())
                            .onTapGesture { onNext() }
                            .transition(.opacity)
                    }
                    bubble(tip, target: rect, in: proxy.size)
                }
                .animation(.spring(duration: 0.4), value: rect)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: tip)
    }

    @ViewBuilder
    private func bubble(_ tip: CoachTip, target: CGRect, in size: CGSize) -> some View {
        let below = target.midY < size.height * 0.5
        let width = min(size.width - 32, 340)
        let left = (size.width - width) / 2
        let arrowX = min(max(target.midX - left, 28), width - 28)
        CoachBubble(tip: tip, step: step, arrowX: arrowX, arrowOnTop: below,
                    showsSkip: onSkip != nil && step != nil,
                    onNext: onNext, onSkip: { onSkip?() })
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .top : .bottom)
            .padding(.top, below ? target.maxY + 10 : 0)
            .padding(.bottom, below ? 0 : size.height - target.minY + 10)
            .id(tip.target)
            .transition(.scale(scale: 0.92, anchor: below ? .top : .bottom).combined(with: .opacity))
    }
}

/// 暗幕。hole の部分だけくり抜き、白い縁で囲む
struct CoachSpotlight: View {
    let hole: CGRect

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .frame(width: hole.width, height: hole.height)
                        .position(x: hole.midX, y: hole.midY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)
                .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }
}

/// 吹き出し本体。相棒が話す形で、矢印は指す部品の側に出す
struct CoachBubble: View {
    let tip: CoachTip
    let step: (index: Int, total: Int)?
    let arrowX: CGFloat
    let arrowOnTop: Bool
    let showsSkip: Bool
    let onNext: () -> Void
    let onSkip: () -> Void

    private var isLast: Bool { step.map { $0.index == $0.total } ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                PartnerIconImage(size: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RenewalTokens.ink)
                    Text(tip.body)
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.ink.opacity(0.8))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                if let step {
                    Text("\(step.index) / \(step.total)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(RenewalTokens.muted)
                }
                Spacer()
                if showsSkip && !isLast {
                    Button("スキップ") {
                        Haptic.impact(.soft)
                        onSkip()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(minWidth: 44, minHeight: 36)
                }
                Button {
                    Haptic.impact(.soft)
                    onNext()
                } label: {
                    Text(step == nil ? "OK" : (isLast ? "はじめる" : "つぎへ"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 36)
                        .background(RenewalTokens.primaryFill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: arrowOnTop ? .topLeading : .bottomLeading) {
            CoachArrow()
                .fill(RenewalTokens.surface)
                .frame(width: 18, height: 9)
                .rotationEffect(.degrees(arrowOnTop ? 0 : 180))
                .offset(x: arrowX - 9, y: arrowOnTop ? -8 : 8)
        }
        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
    }
}

struct CoachArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
