import SwiftUI

struct MainTabView: View {
    @State private var path: [ViewType] = []
    @State private var viewModel: MainTabViewModel = .init()
    @State private var isSheetPresented = false
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

                // 相棒
                Tab(value: MainTabViewModel.Tab.partner) {
                    PartnerView()
                } label: {
                    Label {
                        Text("相棒")
                    } icon: {
                        Image(uiImage: partnerIcon)
                    }
                }

                // クローゼット
                Tab("クローゼット", systemImage: "person.fill", value: MainTabViewModel.Tab.profile) {
                    ProfileView(path: $path)
                }

                // コーデ追加
                Tab("", systemImage: "plus.circle.fill", value: MainTabViewModel.Tab.plus) {
                    EmptyView()
                }
            }
            .environment(viewModel)
            .onChange(of: viewModel.selectedTab) { oldTab, newTab in
                if newTab == .plus {
                    isSheetPresented = true
                    viewModel.selectedTab = previousTab
                } else {
                    previousTab = newTab
                }
            }
            .sheet(isPresented: $isSheetPresented) {
                AddContentModalView(cameraButtonTapped: {
                    path.append(.camera)
                })
                .presentationDetents([.height(200)])
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
                }
            }
        }
        .overlay(alignment: .top) {
            if let message = toastManager.message {
                ToastView(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: toastManager.message)
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
        case planner
        case profile
        case plus
    }
}

// MARK: - AddContentModalView

struct AddContentModalView: View {
    @Environment(\.dismiss) var dismiss
    let cameraButtonTapped: (() -> Void)

    var body: some View {
        VStack(spacing: 12) {
            modalButton(title: "コーディネートを追加", icon: "figure") {
                cameraButtonTapped()
                dismiss()
            }

//            modalButton(title: "アイテムを追加", icon: "tshirt") {
//                dismiss()
//            }

//            modalButton(title: "AIスタイリストとチャット", icon: "person.circle") {
//                dismiss()
//            }
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
