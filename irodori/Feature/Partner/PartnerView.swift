//
//  PartnerView.swift
//  irodori
//
//  Created by Claude on 2026/03/12.
//
//  相棒画面。案E「シンプル + 週報」(PartnerProfileView): ミッション制の理解度と相棒の発見。
//  旧UI「育つ相棒」(PartnerPattern3GrowthView) は残してあるが、ここからは使わない。
//

import SwiftUI

struct PartnerView: View {
    /// タブ全体を包む共有 NavigationStack の path (相棒に相談 → generalChat への push に使う)
    @Binding var path: [ViewType]
    /// シート表示時の閉じるコールバック (NavigationStack push 時は nil)
    var onClose: (() -> Void)? = nil
    @State private var showPartnerOnboardingSheet = false
    @Environment(MainTabViewModel.self) private var tabViewModel: MainTabViewModel?

    var body: some View {
        PartnerProfileView(
            onConsultTap: {
                if let onClose {
                    onClose()
                }
                path.append(.generalChat(conversationId: nil))
            },
            onMissionAction: { action in
                handleMission(action)
            },
            onBrandMatchTap: {
                if let onClose {
                    onClose()
                }
                path.append(.brandMatch)
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

    /// ミッションの行き先へ移動する (相棒画面を閉じてタブを切り替える)
    private func handleMission(_ action: String) {
        // 「この配色で組む」: その服を主役にした3案をホームで組む
        if action.hasPrefix("pivot:") {
            onClose?()
            path.removeAll()
            tabViewModel?.selectedTab = .home
            tabViewModel?.pendingPivotItemId = String(action.dropFirst("pivot:".count))
            return
        }
        switch action {
        case "open_onboarding":
            showPartnerOnboardingSheet = true
        case "open_camera":
            onClose?()
            path.removeAll()
            path.append(.camera)
        case "open_closet", "open_calendar", "open_home":
            onClose?()
            path.removeAll()
            tabViewModel?.selectedTab = action == "open_closet" ? .profile : action == "open_calendar" ? .calendar : .home
        default:
            break
        }
    }
}

#Preview {
    PartnerView(path: .constant([]))
}
