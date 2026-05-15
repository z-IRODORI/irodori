//
//  DailyDesignsCompare.swift
//  irodori - Sandbox
//
//  3案を Picker で切り替えて比較するためのプレビュー画面。
//

import SwiftUI

struct DailyDesignsCompare: View {
    enum Variant: String, CaseIterable, Identifiable {
        case a = "A: バッジ"
        case b = "B: 理由インライン"
        case c = "C: キャプション"
        var id: String { rawValue }
    }

    @State private var variant: Variant = .a
    private let response = SandboxDaily.mockResponse()

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

            switch variant {
            case .a: DailyDesignA(response: response)
            case .b: DailyDesignB(response: response)
            case .c: DailyDesignC(response: response)
            }
        }
    }
}

#Preview("3案 比較") {
    DailyDesignsCompare()
}
