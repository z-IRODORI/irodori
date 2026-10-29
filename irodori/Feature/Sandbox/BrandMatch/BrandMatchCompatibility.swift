//
//  BrandMatchCompatibility.swift
//  irodori - Sandbox
//
//  詳細シートの「あなたとの相性」。
//  ① 好みの一致度 (大きな数字) と「5 つの観点のうち いくつがぴったりか」
//  ② 相棒のひとこと (いちばん近い観点と、いちばん違う観点から決まった言い回しで組み立てる)
//  ③ 5 角形のチャート: あなた (データの色) とブランド (黒の線) を重ねる。観点名をタップで強調
//  ④ 観点ごとの判定 (ぴったり / 近い / ブランドが流行寄り など)
//  値はファッションタイプの点とブランドの見立ての点から計算する (事実ではなく IRODORI の見立て)。
//

import SwiftUI

struct BMCompatibilityView: View {
    let persona: BMPersona
    let brand: BMBrand

    @State private var selected: Int?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: データ

    enum Verdict { case perfect, close, apart }

    struct Axis {
        let name: String
        /// 相棒のひとことで使う言い方 (例: 流行の感じ方)
        let phrase: String
        let user: Double
        let brand: Double
        var diff: Double { brand - user }
        var verdict: Verdict {
            let d = abs(diff)
            return d <= 0.5 ? .perfect : (d <= 1.25 ? .close : .apart)
        }
    }

    private var axes: [Axis] {
        let u = persona.scores
        let b = brand.axes
        return [
            Axis(name: "流行", phrase: "流行の感じ方", user: u[0], brand: b[0]),
            Axis(name: "自分らしさ", phrase: "自分らしさの出し方", user: u[1], brand: b[1]),
            Axis(name: "きちんと感", phrase: "きちんと感の好み", user: u[2], brand: b[2]),
            Axis(name: "着心地", phrase: "着心地へのこだわり", user: u[3], brand: b[3]),
            // 価格: あなたのちょうどいい段階 (6 − 経済の点) と、ブランドの価格の段階
            Axis(name: "価格", phrase: "予算感", user: 6 - persona.economy, brand: Double(brand.tier)),
        ]
    }

    /// 好みの一致度 (価格を除く 4 つの好みの近さ)
    private var percent: Int {
        let total = axes.prefix(4).reduce(0.0) { $0 + abs($1.diff) }
        return Int((100 * (1 - total / 16)).rounded())
    }

    private var perfectCount: Int { axes.filter { $0.verdict == .perfect }.count }

    // MARK: 本体

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(16)
            partnerLine
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            radar
                .frame(height: 248)
                .padding(.horizontal, 8)
            legend
                .padding(.bottom, 12)
            BMRule()
            rows
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(duration: 0.8, bounce: 0.25).delay(0.15)) { appeared = true }
            }
        }
    }

    // MARK: ① 一致度

    private var summary: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("好みの一致度")
                    .font(.system(size: 12))
                    .foregroundStyle(BMTokens.muted)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(percent)")
                        .font(.system(size: 38, weight: .bold).monospacedDigit())
                        .foregroundStyle(BMTokens.ink)
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                }
            }
            .accessibilityElement(children: .combine)

            Rectangle().fill(BMTokens.rule).frame(width: 1, height: 48)

            VStack(alignment: .leading, spacing: 8) {
                Text("5 つの観点のうち \(perfectCount) つがぴったり")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BMTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    ForEach(Array(axes.enumerated()), id: \.offset) { _, a in
                        verdictDot(a.verdict, size: 12)
                    }
                }
                .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: ② 相棒のひとこと

    private var partnerLine: some View {
        HStack(alignment: .top, spacing: 8) {
            BMPartnerIcon(persona: persona, size: 28)
            Text(comment)
                .font(.system(size: 13))
                .foregroundStyle(BMTokens.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BMTokens.raised, in: UnevenRoundedRectangle(
                    topLeadingRadius: 4, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 12,
                    style: .continuous))
        }
    }

    /// いちばん近い観点 + いちばん違う観点 (差が 1.25 を超えるときだけ)
    private var comment: String {
        let list = axes
        // あなたの好みがはっきりしている観点 (3 から 1 以上離れている) を優先して「そっくり」を探す
        let strong = list.indices.filter { abs(list[$0].user - 3) >= 1 }
        let pool = strong.isEmpty ? Array(list.indices) : strong
        let best = pool.min { abs(list[$0].diff) < abs(list[$1].diff) } ?? 0
        var s = abs(list[best].diff) <= 0.5
            ? "\(list[best].phrase)が、あなたとそっくり。"
            : "\(list[best].phrase)が、あなたと近いよ。"
        let worst = list.indices.max { abs(list[$0].diff) < abs(list[$1].diff) } ?? 0
        if list[worst].verdict == .apart {
            s += apartSentence(worst, list[worst].diff > 0)
        } else {
            s += "ほかの観点も、あなたとよく似ているよ"
        }
        return s
    }

    private func apartSentence(_ i: Int, _ up: Bool) -> String {
        switch (i, up) {
        case (0, true): return "流行はブランドの方が一歩先を行っているよ"
        case (0, false): return "ブランドの方が定番寄りで、落ち着いて着られるよ"
        case (1, true): return "ブランドの方が個性が強めだから、いいアクセントになりそう"
        case (1, false): return "ブランドの方が控えめだから、合わせやすいよ"
        case (2, true): return "ブランドの方がきちんと寄りだから、大事な日にも使えそう"
        case (2, false): return "ブランドの方が自由な雰囲気で、休日向きかも"
        case (3, true): return "ブランドの方が着心地重視だから、毎日でもラクに着られそう"
        case (3, false): return "ブランドの方が見た目重視だから、シルエットを楽しめそう"
        case (4, true): return "価格はあなたの予算より少し上。とっておきの一着向きだよ"
        default: return "価格はあなたの予算より手頃だから、気軽に試せるよ"
        }
    }

    // MARK: ③ 5 角形のチャート

    private var radar: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 4)
            let radius = min(geo.size.width, geo.size.height) / 2 - 34
            let list = axes
            ZStack {
                // 目盛りの 5 角形 (1〜5) と軸の線
                ForEach(1...5, id: \.self) { step in
                    Self.polygon(Array(repeating: Double(step), count: 5), center: center, radius: radius)
                        .stroke(step == 5 ? BMTokens.border : BMTokens.rule, lineWidth: 1)
                }
                ForEach(0..<5, id: \.self) { i in
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: Self.point(i, value: 5, center: center, radius: radius))
                    }
                    .stroke(selected == i ? BMTokens.ink : BMTokens.rule, lineWidth: selected == i ? 1.5 : 1)
                }

                // ブランド (黒の線) とあなた (データの色)。開いたときに中心から広がる
                Group {
                    Self.polygon(list.map(\.brand), center: center, radius: radius)
                        .fill(BMTokens.ink.opacity(0.04))
                    Self.polygon(list.map(\.brand), center: center, radius: radius)
                        .stroke(BMTokens.ink, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round, dash: [4, 3]))
                    Self.polygon(list.map(\.user), center: center, radius: radius)
                        .fill(BMTokens.data.opacity(0.16))
                    Self.polygon(list.map(\.user), center: center, radius: radius)
                        .stroke(BMTokens.data, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    ForEach(0..<5, id: \.self) { i in
                        let on = selected == i
                        Circle().fill(BMTokens.surface)
                            .overlay(Circle().stroke(BMTokens.ink, lineWidth: 1.5))
                            .frame(width: on ? 10 : 7, height: on ? 10 : 7)
                            .position(Self.point(i, value: list[i].brand, center: center, radius: radius))
                        Circle().fill(BMTokens.data)
                            .frame(width: on ? 10 : 7, height: on ? 10 : 7)
                            .position(Self.point(i, value: list[i].user, center: center, radius: radius))
                    }
                }
                .scaleEffect(appeared ? 1 : 0.15, anchor: UnitPoint(x: center.x / max(geo.size.width, 1),
                                                                     y: center.y / max(geo.size.height, 1)))
                .opacity(appeared ? 1 : 0)

                // 観点名 (タップで強調)
                ForEach(0..<5, id: \.self) { i in
                    let on = selected == i
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { selected = on ? nil : i }
                        Haptic.selection()
                    } label: {
                        VStack(spacing: 1) {
                            Text(list[i].name)
                                .font(.system(size: 12, weight: on ? .bold : .semibold))
                                .foregroundStyle(BMTokens.ink)
                            verdictDot(list[i].verdict, size: 7)
                        }
                        .frame(minWidth: 56, minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(Self.point(i, value: 5, center: center, radius: radius + 22))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("相性のチャート。\(axes.map { "\($0.name) \(verdictText($0))" }.joined(separator: "、"))"))
    }

    private static func angle(_ i: Int) -> Double { -Double.pi / 2 + 2 * Double.pi * Double(i) / 5 }

    private static func point(_ i: Int, value: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let r = radius * CGFloat(max(0, min(5, value)) / 5)
        return CGPoint(x: center.x + r * CGFloat(cos(angle(i))), y: center.y + r * CGFloat(sin(angle(i))))
    }

    private static func polygon(_ values: [Double], center: CGPoint, radius: CGFloat) -> Path {
        Path { p in
            for (i, v) in values.enumerated() {
                let pt = point(i, value: v, center: center, radius: radius)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(BMTokens.data.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(BMTokens.data, lineWidth: 2))
                    .frame(width: 14, height: 10)
                Text("あなた").font(.system(size: 11)).foregroundStyle(BMTokens.muted)
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(BMTokens.ink, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .frame(width: 14, height: 10)
                Text(brand.nameEn).font(.system(size: 11)).foregroundStyle(BMTokens.muted).lineLimit(1)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: ④ 観点ごとの判定

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(axes.enumerated()), id: \.offset) { i, a in
                if i > 0 { BMRule(leading: 16) }
                let on = selected == i
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selected = on ? nil : i }
                    Haptic.selection()
                } label: {
                    HStack(spacing: 10) {
                        Text(a.name)
                            .font(.system(size: 13, weight: on ? .semibold : .regular))
                            .foregroundStyle(BMTokens.ink)
                            .frame(width: 72, alignment: .leading)
                        verdictDot(a.verdict, size: 10)
                        Text(verdictText(a))
                            .font(.system(size: 13, weight: a.verdict == .apart ? .regular : .semibold))
                            .foregroundStyle(a.verdict == .apart ? BMTokens.muted : BMTokens.data)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 6)
                        miniTrack(a)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(on ? BMTokens.raised : BMTokens.surface)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(a.name)、\(verdictText(a))。あなた \(fmt(a.user))、ブランド \(fmt(a.brand))、5 段階"))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    /// 行の右端: 1〜5 の線の上に、あなた (データの色) とブランド (黒の輪)
    private func miniTrack(_ a: Axis) -> some View {
        let w: CGFloat = 64
        let x = { (v: Double) in CGFloat((max(1, min(5, v)) - 1) / 4) * (w - 10) + 5 }
        return ZStack(alignment: .leading) {
            Rectangle().fill(BMTokens.border).frame(width: w, height: 2)
            Circle().stroke(BMTokens.ink, lineWidth: 1.5).background(Circle().fill(BMTokens.surface))
                .frame(width: 10, height: 10).offset(x: x(a.brand) - 5)
            Circle().fill(BMTokens.data).frame(width: 6, height: 6).offset(x: x(a.user) - 3)
        }
        .frame(width: w, height: 12)
    }

    private func verdictText(_ a: Axis) -> String {
        let isPrice = a.name == "価格"
        switch a.verdict {
        case .perfect: return isPrice ? "予算にぴったり" : "ぴったり"
        case .close: return isPrice ? "予算に近い" : "近い"
        case .apart:
            let up = a.diff > 0
            switch a.name {
            case "流行": return up ? "ブランドが流行寄り" : "ブランドが定番寄り"
            case "自分らしさ": return up ? "ブランドが個性的" : "ブランドが控えめ"
            case "きちんと感": return up ? "ブランドがきちんと寄り" : "ブランドが自由寄り"
            case "着心地": return up ? "ブランドが着心地重視" : "ブランドが見た目重視"
            default: return up ? "予算より高め" : "予算より手頃"
            }
        }
    }

    /// ぴったり = 塗り / 近い = 半分の塗り / 違う = 輪 (色だけでなく形でも分ける)
    @ViewBuilder
    private func verdictDot(_ v: Verdict, size: CGFloat) -> some View {
        switch v {
        case .perfect:
            Circle().fill(BMTokens.data).frame(width: size, height: size)
        case .close:
            Circle().stroke(BMTokens.data, lineWidth: 1.5)
                .background(Circle().trim(from: 0.25, to: 0.75).fill(BMTokens.data).rotationEffect(.degrees(0)))
                .frame(width: size, height: size)
        case .apart:
            Circle().stroke(BMTokens.control, lineWidth: 1.5).frame(width: size, height: size)
        }
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v) }
}
