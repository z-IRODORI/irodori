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
    let viewModel: SplashViewModel = .init()
    let cameraViewModel: CameraViewModel = .init()

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
                case .firstTakePhoto:
                    FirstTakePhotoView(
                        path: $path,
                        viewModel: .init(fashionReviewClient: FashionReviewClient()),
                        okButtonTapped: {
                            viewModel.updateState()
                        }
                    )
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
                }
            }
            .onChange(of: path) { oldValue, newValue in
                // FirstTakePhotoView で分析が完了してホームに戻った時、自動的に .home に遷移
                if viewModel.state == .firstTakePhoto && newValue.isEmpty {
                    viewModel.updateState()
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
