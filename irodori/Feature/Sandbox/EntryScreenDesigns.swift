//
//  EntryScreenDesigns.swift
//  irodori - Sandbox
//
//  初回起動 (利用規約・ログイン) の背景を、3人の写真から相棒を使った画面に替える案 A〜D。
//  どの案も下部 (利用規約・ボタン) は同じで、背景だけを差し替えられる形にしている。
//    A 相棒たちのパレード: 16 タイプの相棒が横に流れていく
//    B 相棒があいさつ: 1 人の相棒が大きく立ち、吹き出しで話しかける
//    C 彩りのタイル: 相棒のアイコンを色とりどりの丸に並べたモザイク (IRODORI = 彩り)
//    D 相棒カード: 3 人の相棒がカードで扇形に広がる
//

import SwiftUI

enum EntryPartnerCast {
    static let all = [
        "クリーン・スタンダード", "トレンド・エディター", "アヴァンギャルド・スター", "ロイヤル・クラシック",
        "アクティブ・クリエイター", "エッセンシャル・ワーカー", "セルフ・ミニマリスト", "ソーシャル・アイコン",
        "オーセンティック・アーティスト", "スマート・フォロワー", "トラッド・コンサバ", "モテ・プランナー",
        "エグゼクティブ・ノマド", "プロフェッショナル・ギア", "ヘビー・デューティー", "ヴィンテージ・ミニマリスト",
    ]
    static let hues: [PartnerHue] = [.pink, .sky, .lemon, .mint, .lilac, .peach]
}

/// 下部の共通部分 (本番の利用規約画面と同じ並び)
private struct EntryFooter: View {
    var dark = false
    var body: some View {
        VStack(spacing: 12) {
            Text("サービスを開始することで以下の利用規約に同意したものとします")
                .font(.system(size: 11))
                .foregroundStyle(dark ? .white.opacity(0.85) : RenewalTokens.muted)
            Text("利用規約")
                .font(.system(size: 12, weight: .semibold))
                .underline()
                .foregroundStyle(dark ? .white : RenewalTokens.ink)
                .padding(.bottom, 12)
            Text("はじめる")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(dark ? .black : .white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(dark ? Color.white : RenewalTokens.primaryFill, in: Capsule())
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 40)
    }
}

private struct EntryLogo: View {
    var dark = false
    var body: some View {
        VStack(spacing: 8) {
            Image(dark ? .logoWhite : .logoBlack)
                .resizable()
                .scaledToFit()
                .frame(width: 210, height: 42)
            Text("今日のコーデに納得を、人生にIRODORIを")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(dark ? .white : RenewalTokens.ink)
        }
    }
}

// MARK: - A 相棒たちのパレード

struct EntryDesignA: View {
    @State private var offset: CGFloat = 0
    private let itemWidth: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)
            EntryLogo()
            Spacer()
            // 16 人を横に並べて、ゆっくり流す (2 周分つないで切れ目を見せない)
            GeometryReader { proxy in
                let row = HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array((EntryPartnerCast.all + EntryPartnerCast.all).enumerated()), id: \.offset) { i, name in
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: itemWidth, height: i % 3 == 0 ? 230 : 200)
                    }
                }
                row
                    .offset(x: offset)
                    .frame(width: proxy.size.width, alignment: .leading)
                    .onAppear {
                        let loop = itemWidth * CGFloat(EntryPartnerCast.all.count)
                        withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { offset = -loop }
                    }
            }
            .frame(height: 240)
            .clipped()
            Rectangle().fill(RenewalTokens.border).frame(height: 1).padding(.horizontal, 24)
            Text("16 タイプの相棒から、あなたの相棒が生まれる")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
                .padding(.top, 10)
            Spacer()
            EntryFooter()
        }
        .background(
            LinearGradient(colors: [PartnerHue.pink.wash, .white, PartnerHue.sky.wash], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

// MARK: - B 相棒があいさつ

struct EntryDesignB: View {
    @State private var index = 0
    @State private var bob = false

    var body: some View {
        let name = EntryPartnerCast.all[index]
        VStack(spacing: 0) {
            Spacer(minLength: 60)
            EntryLogo()
            Spacer()
            VStack(spacing: 6) {
                // 吹き出しは頭の上 (顔を隠さない)
                Text("はじめまして！あなたの相棒になるよ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.white, in: Capsule())
                    .overlay(alignment: .bottom) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .offset(y: 9)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 290)
                    .offset(y: bob ? -4 : 4)
                    .id(name)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity)
            Spacer()
            EntryFooter()
        }
        .background(PartnerHue.lemon.wash.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
        }
        // 数秒ごとに別の相棒に入れ替わる (どんな相棒に会えるかの期待)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(.spring(duration: 0.6)) { index = (index + 1) % EntryPartnerCast.all.count }
            }
        }
    }
}

// MARK: - C 彩りのタイル

struct EntryDesignC: View {
    @State private var appeared = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(EntryPartnerCast.all.enumerated()), id: \.offset) { i, name in
                        let hue = EntryPartnerCast.hues[i % EntryPartnerCast.hues.count]
                        Image("\(name)_icon")
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                            .background(hue.wash, in: Circle())
                            .overlay(Circle().strokeBorder(hue.ink.opacity(0.25), lineWidth: 1))
                            .scaleEffect(appeared ? 1 : 0.4)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(duration: 0.5, bounce: 0.4).delay(Double(i) * 0.04), value: appeared)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 70)
                Spacer()
            }
            // 中央にロゴのカード
            VStack(spacing: 14) {
                EntryLogo()
                Text("あなたの好みを覚える相棒と、\n毎日のコーデを決めよう")
                    .font(.system(size: 13))
                    .foregroundStyle(RenewalTokens.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 22)
            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
            .offset(y: 40)
            VStack { Spacer(); EntryFooter() }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - D 相棒カード

struct EntryDesignD: View {
    @State private var spread = false
    private let trio = [("トレンド・エディター", PartnerHue.sky), ("クリーン・スタンダード", PartnerHue.pink), ("アクティブ・クリエイター", PartnerHue.mint)]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)
            EntryLogo(dark: true)
            Spacer()
            ZStack {
                card(trio[0], angle: spread ? -12 : 0, x: spread ? -96 : 0, y: spread ? 20 : 0, small: true)
                card(trio[2], angle: spread ? 12 : 0, x: spread ? 96 : 0, y: spread ? 20 : 0, small: true)
                card(trio[1], angle: 0, x: 0, y: spread ? -8 : 0, small: false)
            }
            .frame(height: 320)
            Spacer()
            EntryFooter(dark: true)
        }
        .background(RenewalTokens.primaryFill.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.2)) { spread = true }
        }
    }

    private func card(_ item: (String, PartnerHue), angle: Double, x: CGFloat, y: CGFloat, small: Bool) -> some View {
        let w: CGFloat = small ? 124 : 150
        return VStack(spacing: 6) {
            Image(item.0)
                .resizable()
                .scaledToFit()
                .frame(height: w * 1.3)
            Text(item.0)
                .font(.system(size: small ? 9 : 11, weight: .bold))
                .foregroundStyle(item.1.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(width: w)
        .background(item.1.wash, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
        .rotationEffect(.degrees(angle))
        .offset(x: x, y: y)
    }
}

// MARK: - 見比べ

struct EntryScreenDesignsSandboxView: View {
    enum Design: String, CaseIterable, Identifiable {
        case a = "A パレード", b = "B あいさつ", c = "C タイル", d = "D カード"
        var id: String { rawValue }
    }
    @State private var design: Design = .a

    var body: some View {
        VStack(spacing: 0) {
            Picker("案", selection: $design) {
                ForEach(Design.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Group {
                switch design {
                case .a: EntryDesignA()
                case .b: EntryDesignB()
                case .c: EntryDesignC()
                case .d: EntryDesignD()
                }
            }
            .id(design)
        }
        .navigationTitle("初回画面の案")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { EntryScreenDesignsSandboxView() }
}
