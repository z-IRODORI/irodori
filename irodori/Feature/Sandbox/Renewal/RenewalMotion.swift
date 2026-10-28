//
//  RenewalMotion.swift
//  irodori
//
//  ホームの「変わる瞬間だけ」の動き。常に動き続ける演出は使わない。
//   1. 入場: カードが順に浮かび上がり、ボードの服が「トップス → ボトムス → 靴」の順に置かれる (1日1回 / 主役を選んだ直後)
//   2. 主役の服: 選んだ服が画面中央へ飛んで相棒に渡り、組み直した案では主役の服が軽く弾む
//   3. ひとこと: 相棒の言葉を話すように流して表示 (1日1回・タップで全文)。覚えてるよの行は後からふわっと
//  Reduce Motion のときはすべて即時表示。
//

import SwiftUI
import Kingfisher

// MARK: - 環境値

private struct IntroDelayKey: EnvironmentKey { static let defaultValue: Double? = nil }
private struct PulseItemKey: EnvironmentKey { static let defaultValue: String? = nil }

extension EnvironmentValues {
    /// 入場演出の開始までの秒数。nil = 演出なし (即時表示)
    var renewalIntroDelay: Double? {
        get { self[IntroDelayKey.self] }
        set { self[IntroDelayKey.self] = newValue }
    }
    /// 組み直した直後に弾ませる主役の服 (OwnedFirstItem.item_id)
    var renewalPulseItemId: String? {
        get { self[PulseItemKey.self] }
        set { self[PulseItemKey.self] = newValue }
    }
}

// MARK: - 1. 入場

/// カード: 少し下から浮かび上がる。
/// token (入場の回 + 案) ごとに1回だけ。途中でカードが作り直されても、同じ回の入場はもう流さない
/// (作り直しのたびに透明から浮かび直して、案がちらついて見えるのを防ぐ)
struct RenewalIntroRise: ViewModifier {
    let delay: Double?
    var token: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    /// このカードで入場を始めた (始めたカードだけが最後まで動く)
    @State private var startedHere = false

    @MainActor private static var played: Set<String> = []

    func body(content: Content) -> some View {
        let animate = delay != nil && !reduceMotion && (startedHere || !Self.played.contains(token))
        content
            .opacity(!animate || shown ? 1 : 0)
            .offset(y: !animate || shown ? 0 : 18)
            .onAppear {
                guard animate, let delay, !Self.played.contains(token) else { return }
                Self.played.insert(token)
                startedHere = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86).delay(delay)) { shown = true }
            }
    }
}

/// ボードの服: 上からそっと置かれる。主役の服は置かれた後に1回だけ弾む
struct RenewalIntroPlace: ViewModifier {
    let order: Int
    let itemId: String?
    @Environment(\.renewalIntroDelay) private var introDelay
    @Environment(\.renewalPulseItemId) private var pulseId
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var placed = false
    @State private var pulse = false

    func body(content: Content) -> some View {
        let animate = introDelay != nil && !reduceMotion
        content
            .opacity(!animate || placed ? 1 : 0)
            .offset(y: !animate || placed ? 0 : -14)
            .scaleEffect((!animate || placed ? 1 : 0.92) * (pulse ? 1.08 : 1))
            .onAppear {
                guard animate, let introDelay else { return }
                let at = introDelay + Double(order) * 0.09
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72).delay(at)) { placed = true }
                if let pulseId, pulseId == itemId {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(at + 0.35)) { pulse = true }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(at + 0.6)) { pulse = false }
                }
            }
    }
}

// MARK: - 2. 主役の服が相棒へ渡る

/// タップした服の画像を、元の位置から画面中央 (ローディングの正方形) へ飛ばす
struct RenewalFlyingItem: View {
    let imageURL: String
    let from: CGRect          // グローバル座標
    let to: CGPoint           // グローバル座標
    let origin: CGPoint       // このビューのグローバル原点
    @State private var arrived = false

    var body: some View {
        Group {
            if let url = URL(string: imageURL) {
                KFImage(url).resizable().scaledToFit()
            }
        }
        .frame(width: from.width, height: from.height)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .scaleEffect(arrived ? 0.45 : 1)
        .opacity(arrived ? 0 : 1)
        .position(x: (arrived ? to.x : from.midX) - origin.x, y: (arrived ? to.y : from.midY) - origin.y)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) { arrived = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 3. 話すように流れるひとこと

struct RenewalSpokenText: View {
    let text: String
    /// false のときは最初から全文 (2回目以降・Reduce Motion)
    let animate: Bool
    /// タップで全文を出す (ボタンの中に置くときは false にしてタップをボタンへ通す)
    var tapToFinish = true
    var onFinished: () -> Void = {}

    @State private var count = 0
    @State private var finished = false

    var body: some View {
        // 全文を透明で置いて高さを先に確保し、表示済みの文字だけ重ねる (行が増えてガタつかないように)
        Text(text)
            .opacity(0)
            .overlay(alignment: .topLeading) {
                Text(String(text.prefix(finished ? text.count : count)))
            }
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .allowsHitTesting(tapToFinish)
            .task(id: text) {
                guard animate else { finish(); return }
                count = 0
                finished = false
                // 全体で約1.1秒 (長文でも間延びしない)
                let step = max(0.012, min(0.035, 1.1 / Double(max(text.count, 1))))
                for i in 1...max(text.count, 1) {
                    try? await Task.sleep(for: .seconds(step))
                    if Task.isCancelled || finished { return }
                    count = i
                }
                finish()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        count = text.count
        onFinished()
    }
}
