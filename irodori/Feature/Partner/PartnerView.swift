//
//  PartnerView.swift
//  irodori
//
//  Created by Claude on 2026/03/12.
//
//  相棒画面。ベースUIは「育つ相棒」(PartnerPattern3GrowthView)。
//

import SwiftUI

struct PartnerView: View {
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            Text("相棒")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

            // ベースUI: 育つ相棒
            PartnerPattern3GrowthView()
        }
    }
}

#Preview {
    PartnerView()
}
