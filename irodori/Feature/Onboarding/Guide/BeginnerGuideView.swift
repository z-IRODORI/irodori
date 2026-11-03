//
//  BeginnerGuideView.swift
//  irodori
//
//  ファッション感度が 70 点未満の人に、相棒の誕生のあとで見せる 3 枚の案内。
//  見た目は初回のウォークスルーと同じ (白地・大きな見出し・下に黒のボタン・右上にスキップ)。
//  内容は一般的な考え方だけにし、特定の商品やブランドは出さない。
//    1枚目: まずは定番の3着から
//    2枚目: 色は3色までにすると、まとまる
//    3枚目: 持っている定番を教えて →「定番を選ぶ」か「あとで」をユーザーが選ぶ
//

import SwiftUI

struct BeginnerGuideView: View {
    /// 「定番を選ぶ」→ 定番アイテムを選ぶ画面へ
    let onPickStandardItems: () -> Void
    /// 「あとで」「スキップ」→ そのままホームへ
    let onFinish: () -> Void

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Page {
        let symbol: String
        let title: String
        let body: String
        let chips: [String]
    }

    private let pages: [Page] = [
        Page(symbol: "tshirt",
             title: "まずは定番の3着から",
             body: "白のTシャツ、黒のスラックス、白のスニーカーのような組み合わせやすい定番があると、毎日のコーデが組みやすくなるよ。",
             chips: ["白 Tシャツ", "黒 スラックス", "白 スニーカー"]),
        Page(symbol: "paintpalette",
             title: "色は3色までにすると、まとまる",
             body: "白・黒・ネイビーのような落ち着いた色を軸にして、差し色は1か所だけ。それだけで全体がまとまって見えるよ。",
             chips: ["白", "黒", "ネイビー", "＋差し色1か所"]),
        Page(symbol: "hanger",
             title: "持っている定番を教えて",
             body: "持っている定番を教えてくれると、あなたの服だけで組める案が増えるよ。写真はいらないから、選ぶだけ。",
             chips: [])
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("相棒からのアドバイス")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !isLast {
                    Button("スキップ") { onFinish() }
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 24)
            .frame(minHeight: 44)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                    pageView(p).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)

            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.black : Color.gray.opacity(0.25))
                        .frame(width: i == page ? 18 : 6, height: 6)
                }
            }
            .padding(.bottom, 20)
            .accessibilityHidden(true)

            if isLast {
                VStack(spacing: 10) {
                    primaryButton("定番を選ぶ") { onPickStandardItems() }
                    Button {
                        Haptic.selection()
                        onFinish()
                    } label: {
                        Text("あとで")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Text("あとからでも、相棒画面のミッションから選べるよ")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else {
                primaryButton("つぎへ") {
                    withAnimation { page += 1 }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func pageView(_ p: Page) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: p.symbol)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 84, height: 84)
                .background(Color.gray.opacity(0.08), in: Circle())
                .accessibilityHidden(true)
            Text(p.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
            Text(p.body)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            if !p.chips.isEmpty {
                HStack(spacing: 6) {
                    ForEach(p.chips, id: \.self) { chip in
                        Text(chip)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.08), in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.medium)
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BeginnerGuideView(onPickStandardItems: {}, onFinish: {})
}
