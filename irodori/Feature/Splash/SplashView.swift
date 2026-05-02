//
//  SplashView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/09.
//

import SwiftUI

struct SplashView: View {
    @State var path: [ViewType] = []
    @State private var isPresentedTermsOfService = false
    @State private var isStateChanging = false  // state 変更中フラグ
    let viewModel: SplashViewModel = .init()
    let cameraViewModel: CameraViewModel = .init()
    private let toastManager = ToastManager.shared
    private var isHomeState: Bool {
        if case .home = viewModel.state { return true }
        return false
    }

    init() {
        viewModel.updateState()
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch viewModel.state {
                case .termsOfService:
                    SplashView()
                        .sheet(isPresented: $isPresentedTermsOfService) {
                            TermsOfServiceView(viewModel: .init(), hasAgreeToTermsOfService: {
                                viewModel.updateState()
                            })
                        }
                case .userInfo:
                    InputUserInfoView(viewModel: .init(), finishedInputUserInfo: {
                        viewModel.setupSignUpDate()   // アプリインストールしてから一度しか呼ばれない想定
                        viewModel.updateState()
                    })
                case .onboarding:
                    OnboardingView(closeButtonTapped: {
                        viewModel.viewedOnboarding()
                        viewModel.updateState()
                    })
                case .fashionType:
                    NavigationStack(path: $path) {
                        FashionTypeIntroView(path: $path)
                        .navigationDestination(for: ViewType.self) { viewType in
                            switch viewType {
                            case .fashionType:
                                FashionTypeView(
                                    path: $path,
                                    viewModel: .init(apiClient: FashionTypeClient())
                                )
                            case .fashionTypeResult(let response):
                                FashionTypeResultView(
                                    path: $path,
                                    result: response,
                                    onComplete: {
                                        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue)
                                        viewModel.updateState()
                                    }
                                )
                            default:
                                EmptyView()
                            }
                        }
                    }
                case .selectStandardItem:
                    NavigationStack(path: $path) {
                        SelectStandardItemView(
                            path: $path,
                            onComplete: {
                                UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue)
                                viewModel.updateState()
                            }
                        )
                        .navigationDestination(for: ViewType.self) { viewType in
                            switch viewType {
                            case .recommendCoordinateByStandardItem(let params):
                                RecommendCoordinateByStandardItemView(
                                    results: params.results,
                                    selectedItems: params.selectedItems,
                                    onComplete: {
                                        viewModel.updateState()
                                    }
                                )
                            default:
                                EmptyView()
                            }
                        }
                    }
                case .home:
                    MainTabView()
                        .environment(AuthManager.shared)
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
                case .camera:
                    CameraView(cameraViewModel: .init(), path: $path)
                case .calendar:
                    EmptyView() // FirstTakePhotoView からは使用しない
                case .coordinateDetail:
                    EmptyView() // FirstTakePhotoView からは使用しない
                case .profileEdit:
                    EmptyView() // FirstTakePhotoView からは使用しない
                case .fashionType:
                    EmptyView() // FashionType画面は.fashionType stateで直接表示
                case .fashionTypeResult:
                    EmptyView() // FashionType内のNavigationStackで処理
                case .recommendCoordinateByStandardItem(_):
                    EmptyView()
                case .tomorrowPlanner:
                    EmptyView()
                case .generalChat:
                    EmptyView()
                case .chatHistoryList:
                    EmptyView()
                case .chatHistoryDetail:
                    EmptyView()
                }
            }
            // .onChange(of: path) は削除済み（FirstTakePhotoView がオンボーディングから削除されたため不要）
            .onChange(of: viewModel.state) { oldState, newState in
                // state が変わったときに path をクリアして、古い NavigationStack の履歴を削除
                print("🔍 [SplashView] State changed from \(oldState) to \(newState), clearing path")
                isStateChanging = true
                path.removeAll()
                // フラグをリセット（次のフレームで）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isStateChanging = false
                }
            }
//        case .userInfo:
//            InputUserInfoView(viewModel: .init(), finishedInputUserInfo: {
//                viewModel.setupSignUpDate()   // アプリインストールしてから一度しか呼ばれない想定
//                viewModel.updateState()
//            })
//        case .onboarding:
//            OnboardingView(closeButtonTapped: {
//                viewModel.viewedOnboarding()
//                viewModel.updateState()
//            })
//        case .home:
//            MainTabView()
        }
        .overlay(alignment: .top) {
            if !isHomeState, let message = toastManager.message {
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

    private func SplashView() -> some View {
        ZStack {
            Image(.splash01)
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                Image(.logoWhite)
                    .resizable()
                    .frame(width: 250, height: 50)
                Text("今日のコーデに納得を、人生にIRODORIを")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(spacing: 12) {
                Text("サービスを開始することで以下の利用規約に同意したものとします")
                    .foregroundStyle(.white)
                    .font(.system(size: 12, weight: .regular))
                Button(action: {
                    AnalyticsLogger.shared.log(action: .termsAccepted, parameters: [
                        "action": GAEventAction.viewTerms.rawValue
                    ])
                    isPresentedTermsOfService = true
                }) {
                    Text("利用規約")
                        .foregroundStyle(.primary)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.bottom, 24)

                Button(action: {
                    AnalyticsLogger.shared.log(action: .termsAccepted, parameters: [
                        "action": GAEventAction.startService.rawValue
                    ])
                    viewModel.nextButtonTapped()
                }) {
                    Text("次へ")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 40)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}
