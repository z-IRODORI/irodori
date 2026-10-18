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
    /// シート表示時の閉じるコールバック (NavigationStack push 時は nil)
    var onClose: (() -> Void)? = nil
    @State private var showPartnerOnboardingSheet = false

    var body: some View {
        PartnerPattern3GrowthView(
            onConsultTap: {
                if let onClose {
                    onClose()
                }
                path.append(.generalChat(conversationId: nil))
            },
            onRetakeOnboarding: {
                showPartnerOnboardingSheet = true
            }
        )
        .navigationTitle("相棒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        onClose()
                    }
                    .foregroundStyle(.black)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptic.impact(.soft)
                    showPartnerOnboardingSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("4つの質問")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
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
