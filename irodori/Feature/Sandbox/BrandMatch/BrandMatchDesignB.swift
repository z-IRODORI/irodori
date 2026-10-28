//
//  BrandMatchDesignB.swift
//  irodori - Sandbox
//
//  案 B「1 枚ずつめくる」: 10 個を 1 枚ずつ見せる。右へスワイプで「好き」、左で「興味なし」。
//  カードはロゴ・名前・特徴の 1 文・価格・合うところだけ。距離や歴史は「くわしく」の詳細シートへ。
//  スワイプできない人のためにボタンでも同じことができる。
//

import SwiftUI

struct BrandMatchDesignB: View {
    @Bindable var store: BMSandboxStore
    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var opened: BMPick?

    private var picks: [BMPick] { store.persona.picks }

    var body: some View {
        VStack(spacing: 16) {
            progress
            ZStack {
                if index < picks.count {
                    card(picks[index])
                        .overlay(alignment: .topTrailing) { hint }
                        .offset(drag)
                        .rotationEffect(.degrees(Double(drag.width / 24)))
                        // 引っ張っている間だけ浮いている (影は浮いているものにだけ)
                        .shadow(color: .black.opacity(drag == .zero ? 0 : 0.10), radius: 16, y: 6)
                        .gesture(
                            DragGesture()
                                .onChanged { drag = $0.translation }
                                .onEnded { v in
                                    if v.translation.width > 110 { decide(.like) }
                                    else if v.translation.width < -110 { decide(.notInterested) }
                                    else { withAnimation(.spring(duration: 0.3)) { drag = .zero } }
                                }
                        )
                        .id(picks[index].id)
                } else {
                    summary
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            if index < picks.count { buttons }
        }
        .padding(16)
        .background(BMTokens.ground)
        .sheet(item: $opened) { BMDetailSheet(store: store, pick: $0) }
    }

    // MARK: 上: 何枚目か

    private var progress: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(0..<picks.count, id: \.self) { i in
                    Rectangle()
                        .fill(i <= index ? BMTokens.ink : BMTokens.border)
                        .frame(height: 2)
                }
            }
            Text("\(min(index + 1, picks.count)) / \(picks.count)")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(BMTokens.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(picks.count) 個中 \(min(index + 1, picks.count)) 個目"))
    }

    // MARK: カード

    private func card(_ p: BMPick) -> some View {
        let b = p.brand
        return VStack(alignment: .leading, spacing: 0) {
            BMSlotLabel(slot: p.slot)
                .padding(16)
            VStack(alignment: .leading, spacing: 6) {
                BMLogoTile(brand: b, width: 120, height: 80)
                // ブランドのロゴでないときは、何の画像かを書く (運営会社のロゴ・デザイナー など)
                if let img = b.image, img.kind != .brandLogo {
                    Text("画像: " + img.label)
                        .font(.system(size: 11))
                        .foregroundStyle(BMTokens.faint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(b.nameEn)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BMTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(b.nameJa).font(.system(size: 12)).foregroundStyle(BMTokens.muted)
            }
            .padding(16)
            if let summary = b.summary {
                Text(summary)
                    .font(.system(size: 15))
                    .foregroundStyle(BMTokens.ink)
                    .lineSpacing(4)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            BMRule()
            row("価格", b.tierLabel)
            BMRule(leading: 16)
            row("合うところ", p.points.joined(separator: " · "))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .bmCard()
        // スワイプできない人向け: VoiceOver の操作で同じことができる
        .accessibilityAction(named: Text("好き")) { decide(.like) }
        .accessibilityAction(named: Text("興味なし")) { decide(.notInterested) }
        .accessibilityAction(named: Text("くわしく")) { opened = p }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).font(.system(size: 12)).foregroundStyle(BMTokens.muted).frame(width: 64, alignment: .leading)
            Text(value).font(.system(size: 14).monospacedDigit()).foregroundStyle(BMTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 引っ張った向きの答えを、右上に文字で出す
    @ViewBuilder
    private var hint: some View {
        if drag.width > 30 {
            Label("好き", systemImage: "heart.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BMTokens.favorite)
                .padding(16)
        } else if drag.width < -30 {
            Text("興味なし")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BMTokens.muted)
                .padding(16)
        }
    }

    // MARK: 下: ボタン

    private var buttons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button { decide(.notInterested) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(BMTokens.control, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("興味なし"))

                Button { opened = picks[index] } label: {
                    Text("くわしく")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius).stroke(BMTokens.control, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { decide(.like) } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BMTokens.surface)
                        .frame(width: 56, height: 56)
                        .background(BMTokens.favorite, in: Circle())   // 「好き」はお気に入りのピンク
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("好き"))
            }
            Button("どちらでもない（次へ）") { decide(nil) }
                .font(.system(size: 13))
                .foregroundStyle(BMTokens.muted)
                .frame(minHeight: 44)
        }
    }

    private func decide(_ r: BMReaction?) {
        guard index < picks.count else { return }
        let p = picks[index]
        if let r { store.set(r, for: p.brandID); Haptic.impact() }
        let w: CGFloat = r == .like ? 520 : (r == .notInterested ? -520 : 0)
        withAnimation(.easeIn(duration: 0.22)) { drag = CGSize(width: w, height: r == nil ? -700 : 40) }
        Task {
            try? await Task.sleep(for: .milliseconds(240))
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                drag = .zero
                index += 1
            }
        }
    }

    // MARK: 終わり

    private var summary: some View {
        let liked = picks.filter { store.reaction($0.brandID) == .like }
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                BMPartnerIcon(persona: store.persona, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(liked.isEmpty ? "10 個ぜんぶ見たね" : "好きなブランド \(liked.count) 個")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                    Text("教えてくれた反応で、次の 10 選を選び直すね")
                        .font(.system(size: 12))
                        .foregroundStyle(BMTokens.muted)
                }
            }
            if !liked.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(liked.enumerated()), id: \.element.id) { i, p in
                        if i > 0 { BMRule(leading: 92) }
                        Button { opened = p } label: {
                            BMBrandRow(pick: p).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .bmCard()
            }
            Button("最初からめくる") { index = 0 }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BMTokens.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius).stroke(BMTokens.control, lineWidth: 1))
        }
    }
}
