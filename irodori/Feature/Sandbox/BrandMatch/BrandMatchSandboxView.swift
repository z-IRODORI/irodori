//
//  BrandMatchSandboxView.swift
//  irodori - Sandbox
//
//  「あなたに合うブランド 10 選」の見せ方の案 A〜D を見比べる入口。
//  サンプルユーザー 4 人 (ファッションタイプ・年齢・クローゼット) を切り替えられる。
//  ブランドの事実は出典つきの調査マスタの値 (proposals/brand-match/brands.json)、
//  ロゴは Wikimedia Commons か公式サイトの画像 (出典は詳細シートの下)、
//  10 個の選び方は試作 (proposals/brand-match/brand_match.py) と同じ。
//

import SwiftUI

struct BrandMatchSandboxView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case a = "A リスト"
        case b = "B めくる"
        case c = "C 相棒"
        case d = "D 地図"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .a
    @State private var store = BMSandboxStore()

    var body: some View {
        VStack(spacing: 0) {
            controls
            BMRule()
            Group {
                switch tab {
                case .a: BrandMatchDesignA(store: store)
                case .b: BrandMatchDesignB(store: store)
                case .c: BrandMatchDesignC(store: store)
                case .d: BrandMatchDesignD(store: store)
                }
            }
            // ユーザーや案を変えたら、案の画面を作り直す (めくった位置や会話を最初から)
            .id("\(tab.rawValue)-\(store.personaIndex)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("ブランド 10 選の案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("反応を消す") { store.resetPersona() }
                    .font(.system(size: 14))
                    .foregroundStyle(BMTokens.ink)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("案", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Menu {
                ForEach(Array(BMPersona.samples.enumerated()), id: \.element.id) { i, p in
                    Button("\(p.typeName)（\(p.sub)）") { store.personaIndex = i }
                }
            } label: {
                HStack(spacing: 8) {
                    BMPartnerIcon(persona: store.persona, size: 22)
                    Text("\(store.persona.typeName)・\(store.persona.sub)")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("サンプル")
                        .font(.system(size: 12))
                        .foregroundStyle(BMTokens.muted)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(BMTokens.faint)
                }
                .foregroundStyle(BMTokens.ink)
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius).stroke(BMTokens.control, lineWidth: 1))
            }

            Text(summary)
                .font(.system(size: 12))
                .foregroundStyle(BMTokens.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(BMTokens.surface)
    }

    private var summary: String {
        switch tab {
        case .a: return "ZOZOTOWN のようなロゴ一覧。リストとタイルを切り替えられる"
        case .b: return "1 枚ずつめくり、右で好き・左で興味なし。反応が集まる"
        case .c: return "相棒がチャットで 1 つずつ紹介。関係の延長で受け取れる"
        case .d: return "好みの地図で、あなたとの近さを位置で見せる"
        }
    }
}
