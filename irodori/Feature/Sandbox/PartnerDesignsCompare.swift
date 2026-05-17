//
//  PartnerDesignsCompare.swift
//  irodori - Sandbox
//
//  相棒画面ポップ化候補 3 案を Picker で切替して比較するための画面.
//

import SwiftUI

struct PartnerDesignsCompare: View {
    enum Variant: String, CaseIterable, Identifiable {
        case a = "A: 吹き出し"
        case b = "B: チャット"
        case c = "C: トレカ"
        var id: String { rawValue }
    }

    @State private var variant: Variant = .a
    private let insight = PartnerSandbox.mockInsight()

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
            case .a: PartnerDesignA(insight: insight)
            case .b: PartnerDesignB(insight: insight)
            case .c: PartnerDesignC(insight: insight)
            }
        }
    }
}

#Preview("Partner 3案 比較") {
    PartnerDesignsCompare()
}
