//
//  DataOnboardingDesignD.swift
//  irodori - Sandbox
//
//  案D「はじめの3日」: 相棒と過ごす最初の3日でやることを、3つだけ並べる。
//  やることと「済むとどうなるか」を1行ずつ書き、済んだ行にはスタンプが押される。
//  点数は相棒画面のミッションと同じ (closet_5 6 / first_view 3 + first_react 4 / photo_1 5)。
//  実績であることは前に出さず、右端のスタンプと理解度の輪だけで伝える。
//

import SwiftUI

struct DataOnboardingDesignD: View {
    let state: DataOnbSandboxState
    @State private var expanded: Int? = 0
    @State private var reacted = false

    private struct Step: Identifiable {
        let id: Int
        let when: String
        let title: String
        let result: String
        let points: Int
        let channels: [DataOnbChannel]
    }

    private let steps: [Step] = [
        .init(id: 0, when: "今日", title: "持っている服を5点教える",
              result: "手持ちの服で3案を組めるようになる", points: 6, channels: [.fullBody, .standard]),
        .init(id: 1, when: "今日", title: "3案を見て、ひとつに反応する",
              result: "「いいね」「ちょっと違う」で好みが合っていく", points: 7, channels: []),
        .init(id: 2, when: "2日目までに", title: "着た日の全身を1枚撮る",
              result: "実際の合わせ方から、着回しのクセがわかる", points: 5, channels: [.camera]),
    ]

    private func isDone(_ s: Step) -> Bool {
        switch s.id {
        case 0: return state.picked.contains(.fullBody) || state.picked.contains(.standard)
        case 1: return reacted
        default: return state.picked.contains(.camera)
        }
    }

    private var pct: Int { 6 + steps.filter(isDone).map(\.points).reduce(0, +) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    VStack(spacing: 10) {
                        ForEach(steps) { s in stepCard(s) }
                    }
                    Text("済んだ日は、相棒がスタンプを押してくれます")
                        .font(.system(size: 12))
                        .foregroundStyle(RenewalTokens.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            footer
        }
        .background(RenewalTokens.ground)
        .onChange(of: state.picked.isEmpty) { _, empty in
            if empty { reacted = false; expanded = 0 }
        }
    }

    // MARK: 上部: 相棒と理解度の輪

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(RenewalTokens.raised, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(pct) / 100)
                    .stroke(RenewalTokens.accentPink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6), value: pct)
                PartnerIconImage(size: 58)
            }
            .frame(width: 76, height: 76)
            .accessibilityLabel("相棒の理解度 \(pct)%")

            VStack(alignment: .leading, spacing: 6) {
                Text("相棒と過ごす、はじめの3日")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                Text("この3つで、相棒があなたの服をぐっと覚えます")
                    .font(.system(size: 13))
                    .foregroundStyle(RenewalTokens.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("理解度 \(pct)%")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.accentPink)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: pct)
            }
        }
    }

    // MARK: やること

    private func stepCard(_ s: Step) -> some View {
        let done = isDone(s)
        let open = expanded == s.id && !done
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptic.impact(.soft)
                withAnimation(.spring(duration: 0.35)) { expanded = expanded == s.id ? nil : s.id }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.when)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(done ? RenewalTokens.muted : RenewalTokens.accentPink)
                        Text(s.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                            .strikethrough(done, color: RenewalTokens.muted)
                        Text(s.result)
                            .font(.system(size: 12))
                            .foregroundStyle(RenewalTokens.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    stepStamp(s, done: done)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                Divider().overlay(RenewalTokens.rule)
                if s.channels.isEmpty {
                    Button {
                        Haptic.notify(.success)
                        withAnimation(.spring(duration: 0.4)) { reacted = true; expanded = 2 }
                    } label: {
                        Text("Sandbox: 反応したことにする")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(s.channels) { c in
                        DataOnbChannelRow(channel: c, recommended: c == .fullBody) {
                            state.pick(c)
                            withAnimation(.spring(duration: 0.4)) { expanded = s.id + 1 }
                        }
                    }
                }
            }
        }
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(open ? RenewalTokens.ink.opacity(0.7) : RenewalTokens.border, lineWidth: open ? 1.2 : 1)
        )
    }

    /// 右端のスタンプ。まだなら点線の丸、済めば相棒の色で押される
    private func stepStamp(_ s: Step, done: Bool) -> some View {
        let hue: PartnerHue = [.lilac, .sky, .peach][s.id]
        return ZStack {
            Circle()
                .fill(done ? hue.wash : Color.clear)
            Circle()
                .strokeBorder(done ? hue.ink.opacity(0.5) : RenewalTokens.controlBorder,
                              style: StrokeStyle(lineWidth: 1.2, dash: done ? [] : [3, 3]))
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(hue.ink)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
            }
        }
        .frame(width: 40, height: 40)
        .rotationEffect(.degrees(done ? -8 : 0))
        .animation(.spring(duration: 0.45, bounce: 0.5), value: done)
        .accessibilityLabel(done ? "済み" : "まだ")
    }

    // MARK: 下部

    private var footer: some View {
        VStack(spacing: 4) {
            DataOnbPrimaryButton(title: isDone(steps[0]) ? "ホームで3案を見る" : "服を教える") {
                if isDone(steps[0]) {
                    state.finished = true
                } else {
                    withAnimation(.spring(duration: 0.35)) { expanded = 0 }
                }
            }
            if !isDone(steps[0]) {
                DataOnbLaterButton(title: "まずはホームを見る") { state.finished = true }
            } else {
                Text("残りの2つは、ホームの相棒カードからいつでも続けられます")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(RenewalTokens.ground)
    }
}
