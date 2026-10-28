//
//  CoachMarkOverlay.swift
//  irodori
//
//  CoachMarkCenter のツールチップを画面に重ねる層 (MainTabView の一番外側に置く)。
//  - その場型: 吹き出しだけ。吹き出しの外は素通しで、いつもどおり操作できる
//  - ツアー型: 画面を暗くして、指す部品だけをくり抜く。暗幕のどこを押しても次へ
//

import SwiftUI
import UIKit

struct CoachMarkOverlay: View {
    @State private var center = CoachMarkCenter.shared

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            if let tip = center.current, tip.target.screen == center.front,
               let global = targetRect(tip.target, size: proxy.size) {
                let rect = global.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -6, dy: -6)
                let isTour = center.tourStep != nil
                ZStack {
                    if isTour {
                        CoachSpotlight(hole: rect)
                            .contentShape(Rectangle())
                            .onTapGesture { center.next() }
                            .transition(.opacity)
                    }
                    bubble(tip, target: rect, size: proxy.size, isTour: isTour)
                }
                .animation(.spring(duration: 0.4), value: rect)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: center.current)
    }

    /// 指す先の位置 (グローバル)。カメラはシステムのタブバーの中なので、4つ並びの3番目として計算する
    private func targetRect(_ target: CoachTarget, size: CGSize) -> CGRect? {
        if target == .camera {
            let bottom = Self.windowSafeAreaBottom
            let itemWidth = size.width / 4
            return CGRect(x: itemWidth * 2 + (itemWidth - 64) / 2, y: size.height - bottom - 49 + 1, width: 64, height: 47)
        }
        guard let rect = center.frames[target], rect.height > 0 else { return nil }
        // 画面から外れている間は出さない (スクロールで戻ってきたら出る)
        guard rect.maxY > 60, rect.minY < size.height - 60 else { return nil }
        return rect
    }

    private static var windowSafeAreaBottom: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        return window?.safeAreaInsets.bottom ?? 34
    }

    private func bubble(_ tip: CoachTip, target: CGRect, size: CGSize, isTour: Bool) -> some View {
        let below = target.midY < size.height * 0.5
        let width = min(size.width - 32, 340)
        let left = (size.width - width) / 2
        let arrowX = min(max(target.midX - left, 28), width - 28)
        let step = center.tourStep.map { ($0 + 1, center.tourTotal) }
        // 行動ボタンを出すのは、その場型か、ツアーの最後だけ (途中は「つぎへ」で進める)
        let action = (center.tourStep == nil || center.isLastTourStep) ? tip.action : nil
        return CoachBubble(tip: tip, step: step, action: action, arrowX: arrowX, arrowOnTop: below,
                           onNext: { center.next() },
                           onAction: { center.perform($0) },
                           onLater: { center.tourStep != nil ? center.skipTour() : center.next() })
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

/// 吹き出し。相棒が話す形で、矢印は指す部品の側に出す。
/// 行動 (撮る・写真から教える) があるときは、それを黒い主ボタンにして次の行動にする
struct CoachBubble: View {
    let tip: CoachTip
    /// ツアーの「1 / 4」。その場型では nil
    let step: (index: Int, total: Int)?
    let action: CoachAction?
    let arrowX: CGFloat
    let arrowOnTop: Bool
    let onNext: () -> Void
    let onAction: (CoachAction) -> Void
    let onLater: () -> Void

    private var isLast: Bool { step.map { $0.index == $0.total } ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                PartnerIconImage(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tip.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(RenewalTokens.ink)
                    Text(tip.body)
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if let step {
                    Text("\(step.index) / \(step.total)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(RenewalTokens.muted)
                }
                Spacer()
                if let action {
                    secondary(tip.laterLabel, action: onLater)
                    primary(tip.actionLabel) { onAction(action) }
                } else {
                    if step != nil && !isLast { secondary("スキップ", action: onLater) }
                    primary(step == nil ? "OK" : (isLast ? "はじめる" : "つぎへ"), action: onNext)
                }
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

    private func primary(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 40)
                .background(RenewalTokens.primaryFill, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func secondary(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RenewalTokens.muted)
                .padding(.horizontal, 8)
                .frame(minWidth: 44, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
