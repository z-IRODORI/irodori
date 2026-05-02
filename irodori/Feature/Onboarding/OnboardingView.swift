//
//  OnboardingView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/08/02.
//

import SwiftUI

struct OnboardingInfo: Hashable {
    var id: Int
    var title: String
    var description: String
    var imageName: String
}

struct OnboardingView: View {
    let onbordingInfos: [OnboardingInfo] = [
        .init(id: 0, title: "毎日のコーデを撮影", description: "家を出る前 や 明日のコーデを考える時\n 鏡に映る**全身写真**を撮影", imageName: "onboarding1"),
        .init(id: 1, title: "相棒がコーデをレビュー", description: "撮影したコーデをもとに\n相棒が **あなただけ** のレビューをお届け", imageName: "onboarding2")
    ]
    @State private var selectedOnbordingIndex: Int = 0
    let closeButtonTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedOnbordingIndex) {
                ForEach(onbordingInfos, id: \.self) { info in
                    OnboardingCardView(info: info)
                        .tag(info.id)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: selectedOnbordingIndex)

            VStack(spacing: 24) {
                TabIndexView(
                    numberOfPages: onbordingInfos.count,
                    currentIndex: selectedOnbordingIndex,
                    dotSize: 8,
                    spacing: 8
                )

                Button(action: {
                    if selectedOnbordingIndex < onbordingInfos.count - 1 {
                        AnalyticsLogger.shared.log(screen: .onboardingScreenView, parameters: [
                            "action": GAEventAction.nextPage.rawValue,
                            "page_index": selectedOnbordingIndex + 1
                        ])
                        selectedOnbordingIndex += 1
                    } else {
                        AnalyticsLogger.shared.log(screen: .onboardingScreenView, parameters: [
                            "action": GAEventAction.closeOnboarding.rawValue
                        ])
                        closeButtonTapped()
                    }
                }) {
                    Text(selectedOnbordingIndex < onbordingInfos.count - 1 ? "次へ" : "閉じる")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(.white)
        .onAppear {
            AnalyticsLogger.shared.log(screen: .onboardingScreenView)
        }
    }

    private func OnboardingCardView(info: OnboardingInfo) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(info.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)

                Text(.init(info.description))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            Image(info.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
        }
    }
}

#Preview {
    OnboardingView(closeButtonTapped: {})
}
