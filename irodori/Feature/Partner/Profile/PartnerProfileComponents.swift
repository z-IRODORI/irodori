//
//  PartnerProfileComponents.swift
//  irodori
//
//  相棒画面 (案E) の部品: 発見の色・グラフ・返事・ミッションの行・実績シート・発見シート・ふりかえりストーリー。
//  検証は Feature/Sandbox/PartnerProfile (案A〜E)。
//

import Kingfisher
import SwiftUI

// MARK: - 発見の色 (IRODORI = 彩り。発見ごとに1色)

enum PartnerHue: String, Codable, CaseIterable {
    case pink, sky, lemon, mint, lilac, peach

    init(name: String) { self = PartnerHue(rawValue: name) ?? .lilac }

    /// カードの地色 (うすい)
    var wash: Color {
        switch self {
        case .pink: return Color(red: 1.00, green: 0.91, blue: 0.94)
        case .sky: return Color(red: 0.89, green: 0.94, blue: 1.00)
        case .lemon: return Color(red: 1.00, green: 0.96, blue: 0.84)
        case .mint: return Color(red: 0.88, green: 0.97, blue: 0.92)
        case .lilac: return Color(red: 0.94, green: 0.91, blue: 1.00)
        case .peach: return Color(red: 1.00, green: 0.92, blue: 0.86)
        }
    }

    /// 文字・アクセント (白地・wash 地で読める濃さ)
    var ink: Color {
        switch self {
        case .pink: return Color(red: 0.80, green: 0.10, blue: 0.38)
        case .sky: return Color(red: 0.12, green: 0.40, blue: 0.78)
        case .lemon: return Color(red: 0.62, green: 0.45, blue: 0.00)
        case .mint: return Color(red: 0.06, green: 0.52, blue: 0.34)
        case .lilac: return Color(red: 0.44, green: 0.28, blue: 0.80)
        case .peach: return Color(red: 0.78, green: 0.33, blue: 0.10)
        }
    }

    var mid: Color { ink.opacity(0.35) }
}

extension View {
    /// 罫線なしの白カード (IRODORI の白カード + うすい影)
    func partnerSoftCard(_ radius: CGFloat = 18) -> some View {
        background(RenewalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

private extension Color {
    init?(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// 折り返して並べる (チップ用)
struct PartnerFlowChips: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, w: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            w = max(w, x - spacing)
        }
        return CGSize(width: min(w, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: - 発見の裏付けグラフ

struct PartnerProfileVizView: View {
    let viz: PartnerDiscoveryViz
    let hue: PartnerHue

    var body: some View {
        switch viz.type {
        case "colors": colors
        case "items": items
        default: bars
        }
    }

    private var values: [Double] { viz.values ?? [] }

    /// 色の割合 (横に並べた帯)
    private var colors: some View {
        let hexes = viz.colors ?? []
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(viz.labels.enumerated()), id: \.offset) { i, _ in
                        let share = i < values.count ? values[i] : 0
                        let total = max(0.01, values.reduce(0, +))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i < hexes.count ? (Color(hex: hexes[i]) ?? .gray) : .gray)
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.08)))
                            .frame(width: max(8, geo.size.width * share / total - 2))
                    }
                }
            }
            .frame(height: 18)
            HStack(spacing: 10) {
                ForEach(Array(viz.labels.enumerated()), id: \.offset) { i, l in
                    Text("\(l) \(i < values.count ? Int(values[i] * 100) : 0)%")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(RenewalTokens.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 棒 (2本なら横の比較、それ以上は縦棒)
    @ViewBuilder
    private var bars: some View {
        let maxV = max(0.01, values.max() ?? 1)
        if viz.labels.count <= 4 {
            VStack(spacing: 8) {
                ForEach(Array(viz.labels.enumerated()), id: \.offset) { i, label in
                    let v = i < values.count ? values[i] : 0
                    let strong = viz.highlight == i
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundStyle(RenewalTokens.muted)
                            .frame(width: 110, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        GeometryReader { geo in
                            Capsule().fill(strong ? hue.ink : hue.mid)
                                .frame(width: max(8, geo.size.width * CGFloat(v / maxV)))
                        }
                        .frame(height: 8)
                        Text("\(Int(v))\(viz.unit ?? "")")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(strong ? hue.ink : RenewalTokens.muted)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(viz.labels.enumerated()), id: \.offset) { i, label in
                    let v = i < values.count ? values[i] : 0
                    let strong = viz.highlight == i
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(strong ? hue.ink : hue.mid)
                            .frame(width: 14, height: max(6, CGFloat(v / maxV) * 44))
                        Text(label)
                            .font(.system(size: 10, weight: strong ? .bold : .regular))
                            .foregroundStyle(strong ? hue.ink : RenewalTokens.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 64, alignment: .bottom)
            .accessibilityElement(children: .combine)
        }
    }

    /// 手持ちの服の写真を並べる
    private var items: some View {
        let urls = viz.image_urls ?? []
        return HStack(spacing: 10) {
            ForEach(Array(viz.labels.enumerated()), id: \.offset) { i, label in
                VStack(spacing: 4) {
                    Group {
                        if i < urls.count, let url = URL(string: urls[i]) {
                            KFImage(url).resizable().scaledToFit()
                        } else {
                            Image(systemName: "tshirt").foregroundStyle(RenewalTokens.muted)
                        }
                    }
                    .frame(width: 54, height: 54)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(RenewalTokens.muted)
                        .lineLimit(1)
                        .frame(width: 66)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 返事 (相棒の問いかけ → あなたの答え → 相棒の返し)

struct PartnerProfileDigView: View {
    let discovery: PartnerProfileDiscovery
    let onAnswer: (String) -> Void

    var body: some View {
        let hue = PartnerHue(name: discovery.hue)
        let dig = discovery.dig
        VStack(alignment: .leading, spacing: 10) {
            if let q = dig?.question {
                HStack(alignment: .top, spacing: 8) {
                    PartnerIconImage(size: 26)
                    Text(q)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let answer = dig?.answer {
                HStack {
                    Spacer(minLength: 40)
                    Text(answer)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(hue.ink))
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                if let reply = dig?.reply {
                    HStack(alignment: .top, spacing: 8) {
                        PartnerIconImage(size: 26)
                        Text(reply)
                            .font(.system(size: 13))
                            .foregroundStyle(RenewalTokens.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous)
                                    .fill(.white)
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    Label("相棒が覚えた", systemImage: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(hue.ink)
                        .padding(.leading, 34)
                }
            } else if let options = dig?.options, !options.isEmpty {
                PartnerFlowChips(spacing: 6) {
                    ForEach(options, id: \.self) { o in
                        Button {
                            Haptic.impact(.soft)
                            onAnswer(o)
                        } label: {
                            Text(o)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(hue.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(.white))
                                .overlay(Capsule().stroke(hue.mid, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 34)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 発見の詳細シート

struct PartnerProfileDiscoverySheet: View {
    let discovery: PartnerProfileDiscovery
    let onAnswer: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let d = discovery
        let hue = PartnerHue(name: d.hue)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    if let r = d.rarityLabel {
                        Text(r)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(hue.ink))
                    }
                    Text(d.date_label ?? "")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(hue.ink)
                    Spacer()
                    Button("閉じる") { dismiss() }
                        .font(.system(size: 14))
                        .foregroundStyle(RenewalTokens.ink)
                }
                Text(d.headline ?? "")
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let body = d.body {
                    HStack(alignment: .top, spacing: 10) {
                        PartnerIconImage(size: 34)
                        Text(body)
                            .font(.system(size: 14))
                            .lineSpacing(5)
                            .padding(12)
                            .background(
                                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous)
                                    .fill(RenewalTokens.raised)
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let viz = d.viz {
                    PartnerProfileVizView(viz: viz, hue: hue)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(hue.wash))
                }
                PartnerProfileDigView(discovery: d, onAnswer: onAnswer)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(hue.wash.opacity(0.7)))
            }
            .padding(20)
        }
    }
}

// MARK: - ミッションの行

struct PartnerProfileMissionRow: View {
    let mission: PartnerProfileMission
    var onTap: (() -> Void)? = nil

    var body: some View {
        let done = mission.done
        Button {
            Haptic.impact(.soft)
            onTap?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? RenewalTokens.ink : RenewalTokens.raised)
                    if mission.target > 1 && !done && mission.current > 0 {
                        Circle()
                            .trim(from: 0, to: CGFloat(mission.current) / CGFloat(mission.target))
                            .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(1.5)
                    }
                    Image(systemName: done ? "checkmark" : mission.icon)
                        .font(.system(size: 14, weight: done ? .bold : .medium))
                        .foregroundStyle(done ? .white : RenewalTokens.ink)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mission.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(done ? RenewalTokens.muted : RenewalTokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if mission.target > 1 && !done {
                        Text("\(mission.current)/\(mission.target)")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
                Spacer(minLength: 8)
                Text("+\(mission.points)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(done ? RenewalTokens.muted : RenewalTokens.accentPink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(done ? RenewalTokens.raised : RenewalTokens.accentPink.opacity(0.08)))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(done || onTap == nil)
        .accessibilityLabel("\(mission.title)、\(done ? "クリア" : "\(mission.current)/\(mission.target)")、理解度プラス\(mission.points)%")
    }
}

// MARK: - 実績 (全ミッション) シート

struct PartnerProfileMissionsSheet: View {
    let understanding: PartnerUnderstanding
    let missions: [PartnerProfileMission]
    let onAction: (PartnerProfileMission) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(understanding.stages, id: \.index) { s in
                        let list = missions.filter { $0.stage == s.index }
                        let reached = understanding.pct >= s.at_pct
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(s.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(reached ? RenewalTokens.ink : RenewalTokens.muted)
                                Text("\(s.at_pct)%〜")
                                    .font(.system(size: 11))
                                    .monospacedDigit()
                                    .foregroundStyle(RenewalTokens.muted)
                                Spacer()
                                Text("\(list.filter(\.done).count)/\(list.count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(RenewalTokens.muted)
                            }
                            Text(s.unlock)
                                .font(.system(size: 12))
                                .foregroundStyle(RenewalTokens.muted)
                            VStack(spacing: 4) {
                                ForEach(list) { m in
                                    PartnerProfileMissionRow(mission: m) {
                                        dismiss()
                                        onAction(m)
                                    }
                                }
                            }
                            .padding(6)
                            .partnerSoftCard()
                        }
                    }
                }
                .padding(20)
            }
            .background(RenewalTokens.ground)
            .navigationTitle("実績 \(understanding.cleared)/\(understanding.total)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }.foregroundStyle(RenewalTokens.ink)
                }
            }
        }
    }
}

// MARK: - 今週のふりかえり (ストーリー)

struct PartnerProfileStoryPlayer: View {
    let weekly: PartnerWeekly
    let discoveries: [PartnerProfileDiscovery]
    let onAnswer: (PartnerProfileDiscovery, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    private enum Slide {
        case intro
        case number
        case discovery(PartnerProfileDiscovery)
        case ending
    }

    private var slides: [Slide] {
        [.intro, .number] + discoveries.map { .discovery($0) } + (askTarget != nil ? [.ending] : [])
    }

    /// 最後に聞く発見 (まだ返事していないもの)
    private var askTarget: PartnerProfileDiscovery? { discoveries.first(where: \.isWaiting) ?? discoveries.first }

    private var isLast: Bool { index == slides.count - 1 }

    var body: some View {
        let slide = slides[min(index, slides.count - 1)]
        ZStack(alignment: .top) {
            background(slide).ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: index)

            if !isLast {
                // 左 1/3 で戻る、右 2/3 で進む
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle()).frame(maxWidth: .infinity).onTapGesture { back() }
                    Color.clear.contentShape(Rectangle()).frame(maxWidth: .infinity).onTapGesture { next() }
                    Color.clear.contentShape(Rectangle()).frame(maxWidth: .infinity).onTapGesture { next() }
                }
            }

            VStack(spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(slides.indices, id: \.self) { i in
                        Capsule().fill(.white.opacity(i <= index ? 0.95 : 0.3)).frame(height: 3)
                    }
                }
                HStack {
                    PartnerIconImage(size: 30).overlay(Circle().stroke(.white, lineWidth: 1.5))
                    Text("相棒のふりかえり")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                }
                Spacer(minLength: 0)
                content(slide)
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    .allowsHitTesting(isLast)
                Spacer(minLength: 0)
                if !isLast {
                    Text("タップで次へ")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func next() {
        Haptic.impact(.soft)
        withAnimation(.spring(duration: 0.45)) { index = min(slides.count - 1, index + 1) }
    }

    private func back() {
        withAnimation(.spring(duration: 0.45)) { index = max(0, index - 1) }
    }

    private func background(_ s: Slide) -> LinearGradient {
        let pair: [Color]
        switch s {
        case .intro: pair = [PartnerHue.pink.ink, PartnerHue.lilac.ink]
        case .number: pair = [Color(white: 0.1), Color(white: 0.28)]
        case .discovery(let d):
            let h = PartnerHue(name: d.hue)
            pair = [h.ink, h.ink.opacity(0.75)]
        case .ending: pair = [PartnerHue.sky.ink, PartnerHue.mint.ink]
        }
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private func content(_ s: Slide) -> some View {
        switch s {
        case .intro:
            VStack(alignment: .leading, spacing: 14) {
                Text(weekly.range)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("この1週間、\nずっと見てたよ")
                    .font(.system(size: 38, weight: .heavy))
                Text("あなた自身も気づいてないかもしれないこと、\(weekly.count)つ見つけた")
                    .font(.system(size: 16, weight: .medium))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .number:
            VStack(alignment: .leading, spacing: 10) {
                Text(weekly.number.label)
                    .font(.system(size: 18, weight: .bold))
                Text("\(weekly.number.value)\(weekly.number.unit)")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(weekly.number.body)
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(4)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .discovery(let d):
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: d.icon)
                    Text(d.rarityLabel.map { "\($0)な発見" } ?? "発見")
                }
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.2)))
                Text(d.headline ?? "")
                    .font(.system(size: 30, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                if let body = d.body {
                    Text(body)
                        .font(.system(size: 15, weight: .medium))
                        .lineSpacing(4)
                        .opacity(0.92)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let viz = d.viz {
                    PartnerProfileVizView(viz: viz, hue: PartnerHue(name: d.hue))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .ending:
            VStack(alignment: .leading, spacing: 16) {
                Text("ひとつだけ聞かせて")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                if let d = askTarget {
                    PartnerProfileDigView(discovery: d) { onAnswer(d, $0) }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(PartnerHue(name: d.hue).wash))
                }
                Button { back() } label: {
                    Text("前のスライドに戻る")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - あなたに似合う色の組み合わせ (カード)

/// カラーチップ風のカード。上は配色の帯 (割合どおりの高さ)、下に名前・ひとこと・手持ちの服
struct PartnerColorComboCard: View {
    let combo: PartnerColorCombo
    var onBuild: ((String) -> Void)? = nil

    private var tagStyle: (fg: Color, bg: Color, icon: String) {
        switch combo.kind {
        case "liked": return (RenewalTokens.accentPink, RenewalTokens.accentPink.opacity(0.1), "heart.fill")
        case "try": return (PartnerHue.lilac.ink, PartnerHue.lilac.wash, "sparkles")
        default: return (RenewalTokens.ink, RenewalTokens.raised, "checkmark")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chip
            VStack(alignment: .leading, spacing: 8) {
                Label(combo.tag, systemImage: tagStyle.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tagStyle.fg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(tagStyle.bg))
                Text(combo.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(combo.why)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                    .lineSpacing(2)
                    .lineLimit(2, reservesSpace: true)
                HStack(spacing: 8) {
                    // 手持ちの服 (重ねた丸)
                    HStack(spacing: -10) {
                        ForEach(combo.items) { item in
                            Group {
                                if let url = URL(string: item.image_url) {
                                    KFImage(url).resizable().scaledToFit().padding(4)
                                } else {
                                    Image(systemName: "tshirt").foregroundStyle(RenewalTokens.muted)
                                }
                            }
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.white))
                            .overlay(Circle().stroke(RenewalTokens.border, lineWidth: 1))
                            .clipShape(Circle())
                            .accessibilityLabel(item.label)
                        }
                    }
                    Text(combo.hint ?? "手持ちの\(combo.items.count)点で組める")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(combo.kind == "try" ? PartnerHue.lilac.ink : RenewalTokens.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 36)
                if let pivot = combo.pivot_item_id, let onBuild {
                    Button {
                        Haptic.impact(.soft)
                        onBuild(pivot)
                    } label: {
                        HStack(spacing: 4) {
                            Text("この配色で組む")
                            Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Capsule().fill(RenewalTokens.primaryFill))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(14)
        }
        .frame(width: 236)
        .partnerSoftCard(22)
        .accessibilityElement(children: .contain)
    }

    /// 配色の帯。持っていない色は斜線で「足すと完成」を表す
    private var chip: some View {
        VStack(spacing: 0) {
            ForEach(Array(combo.colors.enumerated()), id: \.offset) { _, c in
                let color = Color(hex: c.hex) ?? .gray
                ZStack(alignment: .bottomLeading) {
                    Rectangle().fill(color)
                    if !c.owned {
                        Canvas { ctx, size in
                            var x: CGFloat = -size.height
                            while x < size.width {
                                var p = Path()
                                p.move(to: CGPoint(x: x, y: size.height))
                                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                                ctx.stroke(p, with: .color(.white.opacity(0.55)), lineWidth: 1.5)
                                x += 8
                            }
                        }
                    }
                    HStack(spacing: 4) {
                        Text(c.name)
                            .font(.system(size: 11, weight: .bold))
                        if !c.owned {
                            Text("＋足す")
                                .font(.system(size: 9, weight: .heavy))
                        }
                        Spacer()
                        Text("\(Int((c.ratio * 100).rounded()))%")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .opacity(0.8)
                    }
                    .foregroundStyle(Self.isLight(c.hex) ? RenewalTokens.ink : .white)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
                .frame(height: max(30, 150 * c.ratio))
                .overlay(alignment: .bottom) {
                    // 白どうしが隣り合っても境目が見えるように
                    Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(combo.colors.map { "\($0.name)\(Int($0.ratio * 100))%" }.joined(separator: "、"))
    }

    static func isLight(_ hex: String) -> Bool {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return true }
        let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 170
    }
}
