//
//  LoadingDesignsCompare.swift
//  irodori - Sandbox
//
//  コーデ提案 (レビュー作成) 中のローディング画面 5 案を Picker で切替して比較する画面.
//    A: AI検出スキャン — 撮影画像からトップス/ボトムスを検出する演出 (本命)
//    B: 相棒探索      — 相棒が写真の上を動き回ってコメント
//    C: 相棒トーク    — タイプライター吹き出しで豆知識・進捗を話す
//    D: ミニゲーム    — 落ちてくるアイテムをタップキャッチ
//    E: コーデスロット — リールが回って組み合わせを試すメタファー
//

import SwiftUI

struct LoadingDesignsCompare: View {
    enum Variant: String, CaseIterable, Identifiable {
        case a = "A 検出"
        case b = "B 探索"
        case c = "C 会話"
        case d = "D 遊ぶ"
        case e = "E 抽選"
        var id: String { rawValue }
    }

    @State private var variant: Variant = .a

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $variant) {
                ForEach(Variant.allCases) { v in
                    Text(v.rawValue).tag(v)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white)

            Group {
                switch variant {
                case .a: LoadingDesignA()
                case .b: LoadingDesignB()
                case .c: LoadingDesignC()
                case .d: LoadingDesignD()
                case .e: LoadingDesignE()
                }
            }
            .id(variant)   // 切替時にタイマー / アニメーションを初期化
        }
    }
}

#Preview("ローディング 5案 比較") {
    LoadingDesignsCompare()
}
