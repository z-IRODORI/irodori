//
//  RenewalPartnerLoadingView.swift
//  irodori
//
//  コーデを組んでいる間のローディング。相棒のまわりを「彩り」の色の粒が回り、
//  ひとつずつ相棒に吸い込まれていく (= 色を選んで組み合わせている) 様子を見せる。
//  吹き出しのひとことは、相棒が今していることを数秒ごとに入れ替える。
//  Reduce Motion では粒を止め、ひとことの切り替えだけにする。
//

import SwiftUI

struct RenewalPartnerLoadingView: View {
    let typeName: String
    /// 主役の服を選んで組み直しているときは、その服の名前
    var pinnedLabel: String? = nil
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var messageIndex = 0

    /// IRODORI の「彩り」: 服の定番色から6色
    static let palette: [Color] = [
        Color(red: 0.85, green: 0.11, blue: 0.38),  // ピンク (アクセント)
        Color(red: 0.88, green: 0.48, blue: 0.20),  // オレンジ
        Color(red: 0.91, green: 0.78, blue: 0.30),  // イエロー
        Color(red: 0.27, green: 0.50, blue: 0.34),  // グリーン
        Color(red: 0.25, green: 0.44, blue: 0.71),  // ブルー
        Color(red: 0.85, green: 0.76, blue: 0.64),  // ベージュ
    ]

    private var messages: [String] {
        var m: [String] = []
        if let pinnedLabel { m.append("\(pinnedLabel)に合う服を探してるよ") }
        m += ["クローゼットをのぞいてるよ", "明日の気温をたしかめてるよ", "色の組み合わせを試してるよ", "コーデモデルと見比べてるよ"]
        return m
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            orbit
            Text(messages[messageIndex % messages.count])
                .font(.system(size: compact ? 13 : 14, weight: .medium))
                .foregroundStyle(RenewalTokens.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .padding(.top, 6)   // しっぽの分
                .background(RenewalSpeechBubbleUp().fill(RenewalTokens.surface))
                .overlay(RenewalSpeechBubbleUp().stroke(RenewalTokens.border, lineWidth: 1))
                .id(messageIndex)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 16 : 28)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { messageIndex += 1 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("相棒がコーデを組んでいます")
    }

    private var orbit: some View {
        let avatar: CGFloat = compact ? 52 : 64
        let radius: CGFloat = compact ? 44 : 56
        return TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                // 色の輪 (うっすら)
                Circle()
                    .stroke(AngularGradient(colors: Self.palette + [Self.palette[0]], center: .center), lineWidth: 1.5)
                    .opacity(0.25)
                    .frame(width: radius * 2, height: radius * 2)
                ForEach(0..<Self.palette.count, id: \.self) { i in
                    dot(i, t: t, radius: radius)
                }
                RenewalPartnerAvatar(typeName: typeName, size: avatar)
                    .scaleEffect(reduceMotion ? 1 : 1 + 0.035 * sin(t * 3))
            }
            .frame(width: radius * 2 + 20, height: radius * 2 + 20)
        }
    }

    /// 1粒ずつ回りながら、順番に相棒へ吸い込まれて戻ってくる
    private func dot(_ i: Int, t: Double, radius: CGFloat) -> some View {
        let n = Double(Self.palette.count)
        let angle = t * 0.9 + Double(i) / n * 2 * .pi
        // 6粒が順に 1 周期 (3.6 秒) ずつ相棒に寄る
        let cycle = 3.6
        let phase = (t / cycle * n - Double(i)).truncatingRemainder(dividingBy: n)
        let pull = phase >= 0 && phase < 1 ? sin(phase * .pi) : 0   // 0 → 1 → 0
        let r = radius * (1 - 0.55 * pull)
        let size: CGFloat = 10 + 4 * pull
        return Circle()
            .fill(Self.palette[i])
            .frame(width: size, height: size)
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .shadow(color: Self.palette[i].opacity(0.35), radius: 3)
            .offset(x: CGFloat(cos(angle)) * r, y: CGFloat(sin(angle)) * r)
    }
}

/// 上向きのしっぽが付いた小さな吹き出し (相棒の下に出す)
struct RenewalSpeechBubbleUp: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 6
        let body = CGRect(x: rect.minX, y: rect.minY + tail, width: rect.width, height: rect.height - tail)
        var p = Path(roundedRect: body, cornerRadius: min(14, body.height / 2))
        var t = Path()
        t.move(to: CGPoint(x: rect.midX - 7, y: body.minY + 1))
        t.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        t.addLine(to: CGPoint(x: rect.midX + 7, y: body.minY + 1))
        t.closeSubpath()
        p.addPath(t)
        return p.normalized()
    }
}
