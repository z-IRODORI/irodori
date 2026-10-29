//
//  BrandMatchDesignD.swift
//  irodori - Sandbox
//
//  案 D「好みの地図」: 横 = 定番 ↔ 流行、縦 = きちんと ↔ 自分らしさ の地図に、あなたと 10 ブランドを置く。
//  「なぜこのブランドなのか」を位置で見せる。点をタップすると、地図の下にロゴつきの行が出る。
//  3 つの枠は色ではなく印の形で分ける (ど真ん中 = 塗り / 背伸び = 黒の塗り / はじめまして = 輪)。
//  地図は 4 軸のうち 2 つ (流行と、自己表現 − 社会調和)。着心地と価格は詳細シートで。
//

import SwiftUI

struct BrandMatchDesignD: View {
    @Bindable var store: BMSandboxStore
    @State private var selected = 0
    @State private var opened: BMPick?
    @State private var showsOthers = true

    private var picks: [BMPick] { store.persona.picks }
    private var persona: BMPersona { store.persona }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BMSectionHeader(title: "好みの地図", note: "横は流行、縦は自分らしさ。10 選は価格や雰囲気も合わせて選んでいるので、近い順ではない")
                map
                    .aspectRatio(1, contentMode: .fit)
                    .bmCard()
                HStack(spacing: 14) {
                    ForEach(BMSlot.allCases) { s in
                        HStack(spacing: 5) {
                            mark(s, rank: nil, size: 12)
                            Text(s == .stretch ? "背伸び" : s.title).font(.system(size: 12)).foregroundStyle(BMTokens.muted)
                                .fixedSize()
                        }
                    }
                    Spacer(minLength: 0)
                    Toggle("ほか", isOn: $showsOthers)
                        .font(.system(size: 12))
                        .foregroundStyle(BMTokens.muted)
                        .fixedSize()
                        .tint(BMTokens.primary)
                        .accessibilityLabel(Text("ほかの候補も表示"))
                }
                selectedCard
            }
            .padding(16)
        }
        .background(BMTokens.ground)
        .sheet(item: $opened) { BMDetailSheet(store: store, pick: $0) }
    }

    // MARK: 地図

    private static func point(_ axes: [Double]) -> CGPoint {
        CGPoint(x: (axes[0] - 1) / 4, y: 1 - ((axes[1] - axes[2]) + 4) / 8)
    }

    /// 同じ位置に重なる点を、小さな円の上に散らす
    private func spread(_ items: [(String, CGPoint)], radius: CGFloat) -> [String: CGSize] {
        var groups: [String: [String]] = [:]
        for (id, p) in items {
            groups["\(Int(p.x * 100))|\(Int(p.y * 100))", default: []].append(id)
        }
        var out: [String: CGSize] = [:]
        for ids in groups.values where ids.count > 1 {
            for (i, id) in ids.enumerated() {
                let a = 2 * Double.pi * Double(i) / Double(ids.count) - .pi / 2
                out[id] = CGSize(width: CGFloat(cos(a)) * radius, height: CGFloat(sin(a)) * radius)
            }
        }
        return out
    }

    private var map: some View {
        GeometryReader { geo in
            let inset: CGFloat = 32
            let w = geo.size.width - inset * 2
            let h = geo.size.height - inset * 2
            let place = { (p: CGPoint) in CGPoint(x: inset + p.x * w, y: inset + p.y * h) }
            let pickIDs = Set(picks.map(\.brandID))
            let others = BMBrand.all.values.filter { !pickIDs.contains($0.id) }.sorted { $0.id < $1.id }
            let pickPts = picks.map { ($0.brandID, Self.point($0.brand.axes)) }
            let jitter = spread(pickPts, radius: 24)
            let userPt = place(Self.point(persona.scores))

            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: inset + w / 2, y: inset)); p.addLine(to: CGPoint(x: inset + w / 2, y: inset + h))
                    p.move(to: CGPoint(x: inset, y: inset + h / 2)); p.addLine(to: CGPoint(x: inset + w, y: inset + h / 2))
                }
                .stroke(BMTokens.border, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                axisLabel("流行", at: CGPoint(x: geo.size.width - 22, y: inset + h / 2))
                axisLabel("定番", at: CGPoint(x: 22, y: inset + h / 2))
                axisLabel("自分らしさ", at: CGPoint(x: inset + w / 2, y: 14))
                axisLabel("きちんと", at: CGPoint(x: inset + w / 2, y: geo.size.height - 14))

                if showsOthers {
                    ForEach(Array(others.enumerated()), id: \.element.id) { i, b in
                        let base = place(Self.point(b.axes))
                        let a = Double(i) * 2.399   // 黄金角でずらして重なりを避ける
                        Circle().fill(BMTokens.control)
                            .frame(width: 6, height: 6)
                            .position(x: base.x + CGFloat(cos(a)) * 9, y: base.y + CGFloat(sin(a)) * 9)
                            .accessibilityHidden(true)
                    }
                }

                // あなた (ブランドの点より下に描き、点を隠さない。文字は白い縁で読めるように)
                VStack(spacing: 0) {
                    BMPartnerIcon(persona: persona, size: 26)
                    Text("あなた")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                        .shadow(color: BMTokens.surface, radius: 0, x: 1, y: 1)
                        .shadow(color: BMTokens.surface, radius: 0, x: -1, y: -1)
                }
                .position(x: userPt.x, y: userPt.y)
                .allowsHitTesting(false)
                .accessibilityLabel(Text("あなたの位置"))

                ForEach(Array(picks.enumerated()), id: \.element.id) { i, p in
                    let base = place(pickPts[i].1)
                    let j = jitter[p.brandID] ?? .zero
                    let on = selected == i
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { selected = i }
                        Haptic.selection()
                    } label: {
                        mark(p.slot, rank: i + 1, size: on ? 32 : 28)
                            .overlay(Circle().stroke(BMTokens.ink, lineWidth: on ? 2 : 0).padding(-4))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(x: base.x + j.width, y: base.y + j.height)
                    .zIndex(on ? 2 : 1)
                    .accessibilityLabel(Text("\(i + 1) 番 \(p.brand.nameEn)、\(p.slot.title)"))
                }

            }
        }
    }

    /// 枠の印 (データの色 1 色を塗り方で分ける): ど真ん中 = 塗り / 背伸び = 淡い塗り / はじめまして = 輪。
    /// 黒は「選んでいる点」の輪にだけ使う
    @ViewBuilder
    private func mark(_ slot: BMSlot, rank: Int?, size: CGFloat) -> some View {
        let label = rank.map { Text("\($0)").font(.system(size: max(11, size * 0.42), weight: .semibold).monospacedDigit()) }
        switch slot {
        case .core:
            Circle().fill(BMTokens.data).frame(width: size, height: size)
                .overlay { label?.foregroundStyle(BMTokens.surface) }
        case .stretch:
            Circle().fill(Color(red: 0.80, green: 0.86, blue: 0.95)).frame(width: size, height: size)
                .overlay(Circle().stroke(BMTokens.data, lineWidth: 1))
                .overlay { label?.foregroundStyle(BMTokens.data) }
        case .discover:
            Circle().fill(BMTokens.surface).frame(width: size, height: size)
                .overlay(Circle().stroke(BMTokens.data, lineWidth: 1.5))
                .overlay { label?.foregroundStyle(BMTokens.data) }
        }
    }

    private func axisLabel(_ text: String, at p: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(BMTokens.muted)
            .fixedSize()
            .position(p)
    }

    // MARK: 下: 選んだブランド

    private var selectedCard: some View {
        let p = picks[min(selected, picks.count - 1)]
        return VStack(alignment: .leading, spacing: 0) {
            Button { opened = p } label: {
                BMBrandRow(pick: p, rank: selected + 1, reaction: store.reaction(p.brandID)).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            BMRule()
            HStack(spacing: 0) {
                step("chevron.left", label: "前のブランド", enabled: selected > 0) { selected -= 1 }
                Spacer()
                Text("\(selected + 1) / \(picks.count)・\(p.slot.title)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(BMTokens.muted)
                Spacer()
                step("chevron.right", label: "次のブランド", enabled: selected < picks.count - 1) { selected += 1 }
            }
            .padding(.horizontal, 4)
        }
        .bmCard()
    }

    private func step(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { action() } } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? BMTokens.ink : BMTokens.control)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }
}
