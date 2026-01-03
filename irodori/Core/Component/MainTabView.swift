import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = MainTabViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. 全ての画面を保持し、再描画を防ぐ
            ZStack {
                // ホーム画面
                HomeView()
                    .opacity(viewModel.selectedTab == .home ? 1 : 0)

                // プランナー画面
                PlannerView()
                    .opacity(viewModel.selectedTab == .planner ? 1 : 0)

                // プロフィール画面
                Text("プロフィール画面")
                    .opacity(viewModel.selectedTab == .profile ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 2. カスタムタブバー
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center) {
                tabItem(image: "house", title: "ホーム", isSelected: viewModel.selectedTab == .home) {
                    viewModel.selectedTab = .home
                }

                Spacer()

                // 中央プラスボタン
                plusButton

                Spacer()

                tabItem(image: "person.fill", title: "プロフィール", isSelected: viewModel.selectedTab == .profile) {
                    viewModel.selectedTab = .profile
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 2)
            .background(Color.white)
        }
    }

    private var plusButton: some View {
        Button(action: { viewModel.selectedTab = .planner }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.black)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .offset(y: -20)
    }

    private func tabItem(image: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: image).font(.system(size: 20))
                Text(title).font(.system(size: 12))
            }
            .foregroundStyle(isSelected ? .black : .gray.opacity(0.6))
            .frame(maxWidth: .infinity)
        }
    }

    private var safeAreaBottomPadding: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// 状態管理用のViewModel
class MainTabViewModel: ObservableObject {
    @Published var selectedTab: Tab = .home

    enum Tab {
        case home, planner, profile
    }
}
