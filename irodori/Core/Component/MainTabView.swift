import SwiftUI

struct MainTabView: View {
    @State private var path: [ViewType] = []
    @State private var viewModel: MainTabViewModel = .init()
    @State private var isSheetPresented = false // モーダル管理用フラグ

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ZStack {
                    HomeView()
                        .opacity(viewModel.selectedTab == .home ? 1 : 0)

                    PlannerView()
                        .opacity(viewModel.selectedTab == .planner ? 1 : 0)

                    ProfileView()
                        .opacity(viewModel.selectedTab == .profile ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                customTabBar
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            // モーダルの実装
            .sheet(isPresented: $isSheetPresented) {
                AddContentModalView(cameraButtonTapped: {
                    path.append(.camera)
                })
                    .presentationDetents([.height(300)]) // ハーフモーダルの高さ調整
                    .presentationDragIndicator(.visible)
            }
            .navigationDestination(for: ViewType.self) { viewType in
                switch viewType {
                case .coordinateReview(let capturedImage):
                    CoordinateReviewView(
                        viewModel: .init(
                            coordinateImage: capturedImage!.correctOrientation,
                            apiClient: FashionReviewClient()
                        ),
                        path: $path
                    )
                case .calendar:
                    CalendarView(viewModel: .init(apiClient: CoordinateListClient()), path: $path)
                case .coordinateDetail(let params):
                    CoordinateDetailView(
                        viewModel: .init(uid: params.uid, targetDateString: params.targetDateString, coordinateImageURL: params.coordinateImageURL, coordinateDetailClient: CoordinateDetailClient())
                    )
                case .camera:
                    CameraView(path: $path)
                }
            }
        }
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center) {
                tabItem(image: "house", title: "ホーム", isSelected: viewModel.selectedTab == .home) {
                    viewModel.selectedTab = .home
                }

                Spacer()

                // 中央プラスボタンの修正
                plusButton {
                    isSheetPresented = true // タップでモーダルを表示
                }

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

    private func plusButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
}

@Observable
@MainActor
final class MainTabViewModel {
    var selectedTab: Tab = .home

    enum Tab {
        case home, planner, profile
    }
}

// MARK: - AddContentModalView

/// プラスボタンを押した時に表示するモーダル
struct AddContentModalView: View {
    @Environment(\.dismiss) var dismiss
    let cameraButtonTapped: (() -> Void)

    var body: some View {
        VStack(spacing: 12) {
            modalButton(title: "洋服を追加", icon: "tshirt") {
                // アクション
                dismiss()
            }

            modalButton(title: "アウトフィットを作成", icon: "figure.walk") {
                // アクション
                cameraButtonTapped()
                dismiss()
            }

            modalButton(title: "AIスタイリストとチャット", icon: "person.circle") {
                // アクション
                dismiss()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func modalButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 40)

                Text(title)
                    .font(.system(size: 16, weight: .medium))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
            .padding()
            .background(.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.black)
        }
    }
}
