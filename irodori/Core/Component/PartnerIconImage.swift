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
            if let name = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerIconImage.rawValue),
               UIImage(named: name) != nil {
                Image(name).resizable()
            } else if UIImage(named: "アヴァンギャルド・スター_icon") != nil {
                Image("アヴァンギャルド・スター_icon").resizable()
            } else {
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
