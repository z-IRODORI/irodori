//
//  PartnerIconImage.swift
//  irodori
//
//  Created by Claude on 2026/03/19.
//

import SwiftUI

struct PartnerIconImage: View {
    let size: CGFloat

    init(size: CGFloat = 50) {
        self.size = size
    }

    var body: some View {
        Group {
            // UserDefaultsからpartnerIconImageを取得
            if let partnerIconImageName = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerIconImage.rawValue),
               UIImage(named: partnerIconImageName) != nil {
                Image(partnerIconImageName)
                    .resizable()
            } else if UIImage(named: "アヴァンギャルド・スター_icon") != nil {
                // デフォルト：アヴァンギャルド・スター_icon（灰色）
                Image("アヴァンギャルド・スター_icon")
                    .resizable()
                    .opacity(0.6)  // 灰色効果
            } else {
                // フォールバック：SF Symbol
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#Preview {
    VStack(spacing: 20) {
        PartnerIconImage(size: 50)
        PartnerIconImage(size: 80)
        PartnerIconImage(size: 100)
    }
}
