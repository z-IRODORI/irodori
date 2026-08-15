import SwiftUI

struct MainTabView: View {
    @State private var path: [ViewType] = []
    @State private var viewModel: MainTabViewModel = .init()
    @State private var favoritesStore: FavoritesStore = .init()
    @State private var previousTab: MainTabViewModel.Tab = .home
    private let toastManager = ToastManager.shared

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack(path: $path) {
            TabView(selection: $vm.selectedTab) {
                // ホーム
                Tab("ホーム", systemImage: "house", value: MainTabViewModel.Tab.home) {
                    HomeView(path: $path, viewModel: HomeViewModel(apiClient: HomeClient()))
                }

                // カレンダー (着用記録・予定コーデのふりかえり)
                Tab("カレンダー", systemImage: "calendar", value: MainTabViewModel.Tab.calendar) {
                    CalendarView(viewModel: .init(apiClient: CoordinateListClient()), path: $path)
                }

                // コーデ追加 (中央のカメラ。タブとして留まらず、タップでカメラ画面へ直行)
                // circle.fill 版は黒い円盤になり他タブから浮くため、通常シンボル+ラベルで揃える
                Tab("カメラ", systemImage: "camera", value: MainTabViewModel.Tab.plus) {
                    EmptyView()
                }

                // 相棒
                Tab(value: MainTabViewModel.Tab.partner) {
                    PartnerView(path: $path)
                } label: {
                    Label {
                        Text("相棒")
                    } icon: {
                        Image(uiImage: partnerIcon)
                    }
                }

                // クローゼット
                Tab("クローゼット", systemImage: "tshirt", value: MainTabViewModel.Tab.profile) {
                    ProfileView(path: $path)
                }
            }
            .environment(viewModel)
            .environment(favoritesStore)
            // 選択タブの色をデフォルトの青からアプリ基調の黒に (白カード+黒アクセントの世界観に合わせる)
            .tint(.black)
            .task { await favoritesStore.refresh() }
            // 電話番号⇄user_id の対応表をサーバへ同期 (旧世代UUIDユーザーの遡及紐付け。同期済みなら何もしない)
            .task { await PhoneLinkSyncer.syncIfNeeded() }
            .onChange(of: viewModel.selectedTab) { oldTab, newTab in
                if newTab == .plus {
                    // + はタブとして留まらず、カメラ画面を直接開く
                    viewModel.selectedTab = previousTab
                    path.append(.camera)
                } else {
                    previousTab = newTab
                }
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
                        viewModel: .init(
                            coordinateId: params.coordinateId,
                            coordinateImageURL: params.coordinateImageURL,
                            coordinateDetailClient: CoordinateDetailClient()
                        ),
                        showHeader: params.showHeader
                    )
                case .outfitPlanner:
                    OutfitPlannerView(path: $path)
                case .tomorrowPlanner:
                    TomorrowPlannerView(path: $path)
                case .generalChat(let conversationId):
                    GeneralChatView(
                        path: $path,
                        viewModel: GeneralChatViewModel(apiClient: ChatClient(), conversationId: conversationId)
                    )
                case .camera:
                    CameraView(cameraViewModel: .init(), path: $path)
                case .profileEdit:
                    ProfileEditView(
                        path: $path,
                        profileInfo: getProfileInfo()
                    )
                case .favorites:
                    FavoritesView(path: $path)
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
                case .chatHistoryList:
                    ChatHistoryListView(
                        path: $path,
                        viewModel: ChatHistoryListViewModel(apiClient: ChatClient())
                    )
                case .chatHistoryDetail(let conversationId):
                    ChatHistoryDetailView(
                        path: $path,
                        conversationId: conversationId,
                        viewModel: ChatHistoryDetailViewModel(apiClient: ChatClient())
                    )
                case .coordinateCollage:
                    CoordinateCollageView(viewModel: .init(), path: $path)
                case .outfitSuggestion:
                    OutfitSuggestionView(path: $path)
                case .addItemBySearch:
                    KeywordItemSearchView()
                }
            }
        }
        .overlay(alignment: .top) {
            if let message = toastManager.message {
                ToastView(message: message, style: toastManager.style)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: toastManager.message)
        // NavigationStack 外側に environment を流すことで、
        // .navigationDestination で push する画面 (FavoritesView 等) や
        // .sheet で出すモーダル (DailyRecommendationDetailView 等) にも届く
        .environment(favoritesStore)
        .environment(viewModel)
    }

    private var partnerIcon: UIImage {
        let size = CGSize(width: 30, height: 30)
        let source: UIImage? = {
            if let name = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerIconImage.rawValue),
               let img = UIImage(named: name) { return img }
            if let img = UIImage(named: "アヴァンギャルド・スター_icon") { return img }
            return nil
        }()
        guard let source else {
            return UIImage(systemName: "person") ?? UIImage()
        }
        return UIGraphicsImageRenderer(size: size).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }

    private func getProfileInfo() -> ProfileInfo? {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.profileInfo.rawValue) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(ProfileInfo.self, from: data)
            } catch {
                print("Failed to decode profile info: \(error)")
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.profileInfo.rawValue)
            }
        }

        guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
            return nil
        }

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
}

@Observable
@MainActor
final class MainTabViewModel {
    var selectedTab: Tab = .home
    var shouldShowFirstTakePhotoOnHome: Bool = false

    enum Tab {
        case home
        case partner
        case calendar
        case profile
        case plus
    }
}

