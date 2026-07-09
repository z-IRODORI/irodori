//
//  irodoriApp.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/19.
//

import SwiftUI
import CoreML
import Vision

@main
struct irodoriApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) var scenePhase

    @State private var path: [ViewType] = []

    var body: some Scene {
        WindowGroup {
//            PartnerDesignsCompare()

            LoadingDesignsCompare()

//            SplashView()
//                .onAppear {
//                    AnalyticsLogger.shared.log(screen: .splashScreenView)
//                }
//                .onChange(of: scenePhase) { _, newPhase in
//                    switch newPhase {
//                    case .background:
//                        AnalyticsLogger.shared.log(action: .appBackground)
//                    case .inactive:
//                        AnalyticsLogger.shared.log(action: .appWillResignActive)
//                    case .active:
//                        AnalyticsLogger.shared.log(action: .appDidBecomeActive)
//                    @unknown default:
//                        break
//                    }
//                }

//            FashionTypeIntroView(path: $path)
//                .navigationDestination(for: ViewType.self) { viewType in
//                    switch viewType {
//                    case .fashionType:
//                        FashionTypeView(path: $path, viewModel: FashionTypeViewModel())
//                    case .fashionTypeResult(let response):
//                        FashionTypeResultView(path: $path, result: response)
//                    default:
//                        EmptyView()
//                    }
//                }

//            SelectStandardItemView()

//            // 動作確認用: FashionType -> ResultView
//            NavigationStack(path: $path) {
//                FashionTypeView(
//                    path: $path,
//                    viewModel: FashionTypeViewModel(
//                        apiClient: FashionTypeClient()
//                    )
//                )
//                .navigationDestination(for: ViewType.self) { viewType in
//                    switch viewType {
//                    case .fashionTypeResult(let response):
//                        FashionTypeResultView(
//                            path: $path,
//                            result: response
//                        )
//                    default:
//                        EmptyView()
//                    }
//                }
//            }

//            FashionTypeResultView(
//                path: .constant([]),
//                result: .init(
//                    diagnosis_id: "",
//                    type_code: "",
//                    type_name: "アヴァンギャルド・スター",
//                    trend_score: 2.0, self_score: 2.0, social_score: 2.0, function_score: 2.0, economy_score: 2.0,
//                    created_at: ""
//                ),
//                onComplete: {}
//            )

//            MainTabView()
//                .environment(AuthManager.shared)

//            HomeView()
//            PlannerView()
//            ProfileView()

//            ChatView(
//                coordinateId: "preview-coordinate",
//                image: UIImage(resource: .coordinate7)
//            )

//            CameraView()

//            SelectFirstTimePicView()

//            CoordinateReviewView(viewModel: .init(
//                coordinateImage: UIImage(resource: .coordinate5),
//                apiClient: FashionReviewClient()   //MockFashionReviewClient()
//            ), path: .constant([]))

//            RecommendCoordinateView(
//                viewModel: .init(recommendCoordinateClient: MockRecommendCoordinateClient())
//            )
        }
    }

}
