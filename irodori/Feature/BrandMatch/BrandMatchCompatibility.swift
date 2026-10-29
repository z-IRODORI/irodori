//
//  BrandMatchCompatibility.swift
//  irodori
//
//  詳細シートの上部「好みの一致度」のカード。
//  ① 好みの一致度 (大きな数字) と凡例
//  ② 5 角形のチャート: あなた (黒の線 + 薄いグレーの面) とブランド (グレーの点線) を重ねる
//  ③ 相棒のひとこと (いちばん近い観点と、いちばん違う観点から決まった言い回しで組み立てる)
//  色は使わず白・黒・グレーで描く。観点ごとの判定 (ぴったり / 近い など) は表にせず、相棒のひとことで伝える。
//  値はファッションタイプの点とブランドの見立ての点から計算する (事実ではなく IRODORI の見立て。注意事項に書く)。
//

import SwiftUI

struct BMCompatibilityView: View {
    let persona: BMPersona
    let brand: BMBrand

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

    /// あなた = 黒の線 / ブランド = グレーの点線 (白地で 3:1 以上)
    private static let brandLine = Color(red: 0x8A / 255, green: 0x8F / 255, blue: 0x96 / 255)

    // MARK: 本体

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
                .padding(.horizontal, 18)
                .padding(.top, 16)
            radar
                .frame(height: 228)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            BMRule()
            partnerLine
                .padding(14)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(duration: 0.8, bounce: 0.25).delay(0.15)) { appeared = true }
            }
        }
    }

    // MARK: ① 一致度 + 凡例

    private var head: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("好みの一致度")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BMTokens.muted)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(percent)")
                        .font(.system(size: 44, weight: .bold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 20, weight: .bold))
                }
                .foregroundStyle(BMTokens.ink)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            legend
                .padding(.bottom, 9)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(BMTokens.ink.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(BMTokens.ink, lineWidth: 2))
                    .frame(width: 16, height: 10)
                Text("あなた")
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Self.brandLine, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .frame(width: 16, height: 10)
                Text(brand.nameEn).lineLimit(1)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(BMTokens.muted)
        .frame(maxWidth: 150, alignment: .leading)
        .accessibilityHidden(true)
    }

    // MARK: ② 5 角形のチャート

    private var radar: some View {
        GeometryReader { geo in
            // 5 角形は下が浅いので、中心を少し下げて上下の余白をそろえる
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 10)
            let radius = min(geo.size.width, geo.size.height) / 2 - 26
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
                    .stroke(BMTokens.rule, lineWidth: 1)
                }

                // ブランド (グレーの点線) とあなた (黒の線 + 薄い面)。開いたときに中心から広がる
                Group {
                    Self.polygon(list.map(\.brand), center: center, radius: radius)
                        .stroke(Self.brandLine, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round, dash: [4, 3]))
                    Self.polygon(list.map(\.user), center: center, radius: radius)
                        .fill(BMTokens.ink.opacity(0.08))
                    Self.polygon(list.map(\.user), center: center, radius: radius)
                        .stroke(BMTokens.ink, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    ForEach(0..<5, id: \.self) { i in
                        Circle().fill(BMTokens.surface)
                            .overlay(Circle().stroke(Self.brandLine, lineWidth: 1.5))
                            .frame(width: 7, height: 7)
                            .position(Self.point(i, value: list[i].brand, center: center, radius: radius))
                        Circle().fill(BMTokens.ink)
                            .frame(width: 7, height: 7)
                            .position(Self.point(i, value: list[i].user, center: center, radius: radius))
                    }
                }
                .scaleEffect(appeared ? 1 : 0.15, anchor: UnitPoint(x: center.x / max(geo.size.width, 1),
                                                                     y: center.y / max(geo.size.height, 1)))
                .opacity(appeared ? 1 : 0)

                // 観点名
                ForEach(0..<5, id: \.self) { i in
                    Text(list[i].name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                        .fixedSize()
                        .position(Self.point(i, value: 5, center: center, radius: radius + 18))
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

    // MARK: ③ 相棒のひとこと

    private var partnerLine: some View {
        HStack(alignment: .top, spacing: 10) {
            BMPartnerIcon(persona: persona, size: 32)
            Text(comment)
                .font(.system(size: 14))
                .foregroundStyle(BMTokens.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BMTokens.raised, in: UnevenRoundedRectangle(
                    topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14,
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

    /// 読み上げ用の観点ごとの判定
    private func verdictText(_ a: Axis) -> String {
        let isPrice = a.name == "価格"
        switch a.verdict {
        case .perfect: return isPrice ? "予算にぴったり" : "あなたとそっくり"
        case .close: return isPrice ? "予算に近い" : "あなたと近い"
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
}
