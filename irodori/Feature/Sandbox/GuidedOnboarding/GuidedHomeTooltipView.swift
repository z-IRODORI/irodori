//
//  GuidedHomeTooltipView.swift
//  irodori - Sandbox
//
//  ツールチップ型: 相棒誕生のあと、初めてホームを開いたときに部品を指して教える。
//  ホームは本番 (RenewalLiveHomeView + PartnerGrowthCard + タブ) の並びを見本で再現している。
//
//  2つの出し方を見比べる:
//  - ツアー型: 来た直後に4つを順に。画面を暗くして1つずつくり抜く。いつでもスキップできる
//  - その場型: 必要になった瞬間に1つずつ。暗くしない
//      来た直後 → 相棒のひとこと / 相棒カードが見えたら → 服を教えて /
//      「ちょっと違う」を押したら → 理由で組み直す / 「着る」を押したら → 着た日は撮ろう
//  どちらも1回見たら二度と出さない (本番は UserDefaults に記録)。
//

import SwiftUI

struct GuidedHomeTooltipView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case tour = "ツアー型"
        case contextual = "その場型"
        var id: String { rawValue }
    }

    let mode: Mode

    // ツアー型
    private let tourSteps: [CoachTip] = [.partner, .recipes, .growth, .camera]
    @State private var tourIndex: Int? = nil

    // その場型
    @State private var queue: [CoachTip] = []
    @State private var seen: Set<CoachTarget> = []

    // 見本の操作
    @State private var decided = false
    @State private var disliked = false

    private var currentTip: CoachTip? {
        switch mode {
        case .tour: return tourIndex.map { tourSteps[$0] }
        case .contextual: return queue.first
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        partnerCard
                            .coachAnchor(.partner).id(CoachTarget.partner)
                        Text("明日の3案")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(RenewalTokens.ink)
                            .padding(.top, 4)
                        VStack(spacing: 12) {
                            recipeCard(0, title: "白シャツ × ネイビーのワイドパンツ", first: true)
                                .coachAnchor(.recipes).id(CoachTarget.recipes)
                            recipeCard(1, title: "ベージュのニット × ブラウンのパンツ", first: false)
                            recipeCard(2, title: "黒のカーディガン × グレーのスラックス", first: false)
                        }
                        growthCard
                            .coachAnchor(.growth).id(CoachTarget.growth)
                            .onScrollVisibilityChange(threshold: 0.7) { visible in
                                if visible { trigger(.growth) }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 24)
                }
                .scrollDisabled(mode == .tour && tourIndex != nil)
                tabBar
            }
            .background(RenewalTokens.ground)
            .overlayPreferenceValue(CoachAnchorKey.self) { anchors in
                CoachMarkLayer(
                    anchors: anchors,
                    tip: currentTip,
                    spotlight: mode == .tour,
                    step: mode == .tour ? tourIndex.map { ($0 + 1, tourSteps.count) } : nil,
                    onNext: { advance(proxy) },
                    onSkip: { withAnimation { tourIndex = nil } }
                )
            }
            .task(id: mode) { await start(proxy) }
        }
    }

    // MARK: 進め方

    private func start(_ proxy: ScrollViewProxy) async {
        tourIndex = nil
        queue = []
        seen = []
        decided = false
        disliked = false
        proxy.scrollTo(CoachTarget.partner, anchor: .top)
        try? await Task.sleep(for: .seconds(0.8))
        switch mode {
        case .tour: withAnimation { tourIndex = 0 }
        case .contextual: trigger(.partner)
        }
    }

    private func advance(_ proxy: ScrollViewProxy) {
        switch mode {
        case .tour:
            guard let i = tourIndex else { return }
            let next = i + 1
            guard next < tourSteps.count else { withAnimation { tourIndex = nil }; return }
            let target = tourSteps[next].target
            if target != .camera {
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(target, anchor: .center) }
            }
            withAnimation { tourIndex = next }
        case .contextual:
            guard !queue.isEmpty else { return }
            withAnimation { _ = queue.removeFirst() }
        }
    }

    /// その場型: その部品が必要になった瞬間に1回だけ出す
    private func trigger(_ target: CoachTarget) {
        guard mode == .contextual, !seen.contains(target) else { return }
        let tip: CoachTip
        switch target {
        case .partner: tip = .partner
        case .recipes: tip = .recipes
        case .feedback: tip = .feedback
        case .growth: tip = .growth
        case .camera: tip = .camera
        }
        seen.insert(target)
        withAnimation { queue.append(tip) }
    }

    // MARK: 見本のホーム

    private var header: some View {
        ZStack {
            Text("ホーム")
                .font(.system(size: 18, weight: .semibold))
            HStack(spacing: 18) {
                Spacer()
                Image(systemName: "heart")
                Image(systemName: "calendar")
            }
            .font(.system(size: 17))
            .padding(.horizontal, 16)
        }
        .foregroundStyle(RenewalTokens.ink)
        .frame(height: 48)
        .background(RenewalTokens.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(RenewalTokens.rule).frame(height: 1) }
    }

    private var partnerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            PartnerIconImage(size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("明日 10/27(月)  18° / 12°")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
                Text("はじめまして！まずは答えてくれた好みから、明日の3案を組んでみたよ。")
                    .font(.system(size: 14))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
        }
        .padding(14)
        .renewalCard()
    }

    private static let palettes: [[Color]] = [
        [Color(white: 0.96), Color(red: 0.20, green: 0.27, blue: 0.40), Color(white: 0.15)],
        [Color(red: 0.93, green: 0.90, blue: 0.84), Color(red: 0.38, green: 0.33, blue: 0.27), Color(white: 0.92)],
        [Color(red: 0.12, green: 0.12, blue: 0.13), Color(red: 0.62, green: 0.62, blue: 0.60), Color(white: 0.15)],
    ]

    private func recipeCard(_ index: Int, title: String, first: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { p in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Self.palettes[index][p])
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.black.opacity(0.08)))
                            .frame(width: 52, height: p == 2 ? 30 : 64)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    if first {
                        Text("イチオシ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RenewalTokens.accentPink)
                    }
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("見本")
                        .font(.system(size: 10))
                        .foregroundStyle(RenewalTokens.muted)
                }
                Spacer(minLength: 0)
            }
            feedbackRow(first: first)
                .modifier(OptionalCoachAnchor(target: first ? .feedback : nil))
        }
        .padding(14)
        .renewalCard()
    }

    private func feedbackRow(first: Bool) -> some View {
        HStack(spacing: 8) {
            pill(first && disliked ? "見送り中" : "ちょっと違う", icon: "hand.thumbsdown", on: first && disliked) {
                guard first else { return }
                withAnimation { disliked = true }
                trigger(.feedback)
            }
            pill("いいね", icon: "hand.thumbsup", on: false) {}
            Spacer(minLength: 0)
            Button {
                Haptic.impact(.medium)
                guard first else { return }
                withAnimation { decided = true }
                trigger(.camera)
            } label: {
                Text(first && decided ? "着る予定" : "着る")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(first && decided ? RenewalTokens.ink : .white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 36)
                    .background(first && decided ? RenewalTokens.raised : RenewalTokens.primaryFill, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func pill(_ text: String, icon: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: on ? "\(icon).fill" : icon).font(.system(size: 11))
                Text(text).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(RenewalTokens.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(on ? RenewalTokens.raised : RenewalTokens.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(RenewalTokens.border))
        }
        .buttonStyle(.plain)
    }

    private var growthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("相棒があなたのことを知りたがっています")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                Spacer(minLength: 0)
            }
            Text("相棒の理解度 6%  ・  覚えた服 0点")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(RenewalTokens.muted)
            VStack(spacing: 0) {
                growthRow("person.crop.rectangle.stack", "あなたの全身写真を見せて", "写真フォルダからAIが自動で探すよ")
                Divider().overlay(RenewalTokens.rule).padding(.leading, 52)
                growthRow("tshirt", "持っている服を教えて", "定番アイテムを選ぶだけ。写真はいらないよ")
                Divider().overlay(RenewalTokens.rule).padding(.leading, 52)
                growthRow("hand.thumbsup", "好きなコーデを教えて", "2つを見比べて選ぶだけ")
            }
            .background(RenewalTokens.ground)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
        }
        .padding(16)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func growthRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(RenewalTokens.ink)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(RenewalTokens.ink)
                Text(detail).font(.system(size: 11)).foregroundStyle(RenewalTokens.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 60)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem("house.fill", "ホーム", on: true)
            tabItem("person.2", "相棒", on: false)
            ZStack {
                Circle().fill(RenewalTokens.primaryFill).frame(width: 52, height: 52)
                Image(systemName: "camera.fill").font(.system(size: 20)).foregroundStyle(.white)
            }
            .coachAnchor(.camera)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("コーデを記録")
            tabItem("calendar", "カレンダー", on: false)
            tabItem("person", "プロフィール", on: false)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(RenewalTokens.surface)
        .overlay(alignment: .top) { Rectangle().fill(RenewalTokens.rule).frame(height: 1) }
    }

    private func tabItem(_ icon: String, _ label: String, on: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 18))
            Text(label).font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(on ? RenewalTokens.ink : RenewalTokens.muted)
        .frame(maxWidth: .infinity)
    }
}

/// 1枚目の案の反応行だけを指せるようにする
private struct OptionalCoachAnchor: ViewModifier {
    let target: CoachTarget?
    func body(content: Content) -> some View {
        if let target { content.coachAnchor(target) } else { content }
    }
}
