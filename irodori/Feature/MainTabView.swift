import SwiftUI

struct MainTabView: View {
    @State private var path: [ViewType] = []
    @State private var viewModel: MainTabViewModel = .init()
    @State private var isSheetPresented = false // モーダル管理用フラグ

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ZStack {
                    HomeView(path: $path)
                        .opacity(viewModel.selectedTab == .home ? 1 : 0)
                        .environment(viewModel)

                    PlannerView()
                        .opacity(viewModel.selectedTab == .planner ? 1 : 0)

                    PartnerView()
                        .opacity(viewModel.selectedTab == .partner ? 1 : 0)

                    ProfileView(path: $path)
                        .opacity(viewModel.selectedTab == .profile ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)

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
                case .coordinateReview(let params):
                    CoordinateReviewView(
                        viewModel: .init(
                            coordinateImage: params.image!.correctOrientation,
                            apiClient: FashionReviewClient()
                        ),
                        fromFirstTakePhotoView: params.fromFirstTakePhotoView,
                        path: $path
                    )
                case .calendar:
                    CalendarView(viewModel: .init(apiClient: CoordinateListClient()), path: $path)
                        .environment(viewModel)
                case .coordinateDetail(let params):
                    CoordinateDetailView(
                        viewModel: .init(uid: params.uid, targetDateString: params.targetDateString, coordinateImageURL: params.coordinateImageURL, coordinateDetailClient: CoordinateDetailClient()),
                        showHeader: params.showHeader
                    )
                case .camera:
                    CameraView(cameraViewModel: .init(), path: $path)
                case .profileEdit:
                    ProfileEditView(
                        path: $path,
                        profileInfo: getProfileInfo()
                    )
                case .fashionType:
                    FashionTypeView(
                        path: $path,
                        viewModel: .init(apiClient: FashionTypeClient())
                    )
                case .fashionTypeResult(let response):
                    FashionTypeResultView(
                        path: $path,
                        result: response
                    )
                case .recommendCoordinateByStandardItem(_):
                    EmptyView()
                }
            }
        }
    }

    private func getProfileInfo() -> ProfileInfo? {
        // 既存のプロフィール情報を取得を試みる
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.profileInfo.rawValue) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(ProfileInfo.self, from: data)
            } catch {
                print("Failed to decode profile info: \(error)")
                // デコードエラーが発生した場合、古いデータを削除
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.profileInfo.rawValue)
            }
        }

        // プロフィール情報がない、またはデコードに失敗した場合、デフォルトプロフィールを作成
        guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
            return nil
        }

        // User情報からデフォルトプロフィールを作成
        var username = uid
        if let userData = UserDefaults.standard.data(forKey: UserDefaultsKey.userInfo.rawValue),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            username = user.username
        }

        let defaultProfile = ProfileInfo(
            id: uid,
            username: username,
            displayName: username,
            profileImageUrl: nil,
            createdAt: Date(),
            lastLoginAt: nil
        )

        // デフォルトプロフィールを保存
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(defaultProfile)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.profileInfo.rawValue)
        } catch {
            print("Failed to save default profile info: \(error)")
        }

        return defaultProfile
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center) {
                tabItem(image: "house", title: "ホーム", isSelected: viewModel.selectedTab == .home) {
                    viewModel.selectedTab = .home
                }

                Spacer()

                partnerTabItem(title: "相棒", isSelected: viewModel.selectedTab == .partner) {
                    viewModel.selectedTab = .partner
                }

                Spacer()

                tabItem(image: "person.fill", title: "クローゼット", isSelected: viewModel.selectedTab == .profile) {
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

    private func partnerTabItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // UserDefaultsからpartnerIconImageを取得
                if let partnerIconImageName = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerIconImage.rawValue),
                   UIImage(named: partnerIconImageName) != nil {
                    Image(partnerIconImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                } else {
                    // フォールバック：アヴァンギャルド・スター_icon
                    if UIImage(named: "アヴァンギャルド・スター_icon") != nil {
                        Image("アヴァンギャルド・スター_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    } else {
                        // さらにフォールバック：SF Symbol
                        Image(systemName: "person")
                            .font(.system(size: 28))
                    }
                }
                Text(title).font(.system(size: 12))
            }
            .foregroundStyle(isSelected ? .black : .gray.opacity(0.3))
            .frame(maxWidth: .infinity)
        }
    }
}

@Observable
@MainActor
final class MainTabViewModel {
    var selectedTab: Tab = .home
    var shouldShowFirstTakePhotoOnHome: Bool = false

    enum Tab {
        case home
        case partner
        case planner
        case profile
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
