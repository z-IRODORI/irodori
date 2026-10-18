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
    /// タブ全体を包む共有 NavigationStack の path (相棒に相談 → generalChat への push に使う)
    @Binding var path: [ViewType]
    @State private var showPartnerOnboardingSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            ZStack {
                Text("相棒")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)

                HStack {
                    Spacer()
                    Button {
                        Haptic.impact(.soft)
                        showPartnerOnboardingSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                            Text("4つの質問")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // ベースUI: 育つ相棒
            PartnerPattern3GrowthView(onConsultTap: {
                path.append(.generalChat(conversationId: nil))
            })
        }
        .fullScreenCover(isPresented: $showPartnerOnboardingSheet) {
            PartnerOnboardingFlowView(
                showCloseButton: true,
                onComplete: {
                    showPartnerOnboardingSheet = false
                }
            )
        }
    }
}

#Preview {
    PartnerView(path: .constant([]))
}
