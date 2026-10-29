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

    /// タブとして表示するとき true。ホームと同じく、見出しと「4つの質問」を画面の上部に自前で描く
    /// (タブを包む NavigationStack の外側にあるため、タブの中の toolbar はナビゲーションバーに出ない)
    var isTab = false

    var body: some View {
        Group {
            if isTab {
                VStack(spacing: 0) {
                    ZStack {
                        Text("相棒")
                            .font(.system(size: 18, weight: .semibold))
                        HStack {
                            Spacer()
                            questionsButton
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white)
                    // ヘッダーの下に細い線 (ホーム・カレンダー・クローゼットとそろえる)
                    Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 0.5)
                    profile
                }
            } else {
                profile
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
                            questionsButton
                        }
                    }
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

    private var profile: some View {
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
    }

    /// 4つの質問に答え直す (相棒のタイプを決め直す)
    private var questionsButton: some View {
        Button {
            Haptic.impact(.soft)
            showPartnerOnboardingSheet = true
        } label: {
            // 文字は出さずアイコンだけ (見た目 32pt の丸、押せる範囲は 44pt)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(Color.gray.opacity(0.1), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("4つの質問に答え直す")
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
        case "open_brands":
            // 「ブランドの価格帯を教える」: あなたに合うブランドの一覧へ
            onClose?()
            path.append(.brandMatch)
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
