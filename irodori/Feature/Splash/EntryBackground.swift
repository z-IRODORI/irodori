//
//  EntryBackground.swift
//  irodori
//
//  起動直後の画面 (利用規約・ログイン・アカウント確認中) で共通に使う背景。
//  16 タイプの相棒のアイコンを色とりどりの丸に並べ (IRODORI = 彩り)、中央にロゴのカードを置く。
//  (Sandbox「初回起動の画面」案 C。以前は 3 人の写真で、画面ごとに見え方が違っていた)
//  白地なので、上に重ねる文字・ボタンは黒系で書く。
//

import SwiftUI

struct EntryBackground: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cast = [
        "クリーン・スタンダード", "トレンド・エディター", "アヴァンギャルド・スター", "ロイヤル・クラシック",
        "アクティブ・クリエイター", "エッセンシャル・ワーカー", "セルフ・ミニマリスト", "ソーシャル・アイコン",
        "オーセンティック・アーティスト", "スマート・フォロワー", "トラッド・コンサバ", "モテ・プランナー",
        "エグゼクティブ・ノマド", "プロフェッショナル・ギア", "ヘビー・デューティー", "ヴィンテージ・ミニマリスト",
    ]
    private static let hues: [PartnerHue] = [.pink, .sky, .lemon, .mint, .lilac, .peach]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(Self.cast.enumerated()), id: \.offset) { i, name in
                        let hue = Self.hues[i % Self.hues.count]
                        Image("\(name)_icon")
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                            .background(hue.wash, in: Circle())
                            .overlay(Circle().strokeBorder(hue.ink.opacity(0.25), lineWidth: 1))
                            .scaleEffect(appeared ? 1 : 0.4)
                            .opacity(appeared ? 1 : 0)
                            .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.4).delay(Double(i) * 0.04),
                                       value: appeared)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                Spacer(minLength: 0)
            }
            .accessibilityHidden(true)

            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    Image(.logoBlack)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 42)
                    Text("今日のコーデに納得を、人生にIRODORIを")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                }
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
        }
        .onAppear { appeared = true }
    }
}

#Preview {
    EntryBackground()
}
