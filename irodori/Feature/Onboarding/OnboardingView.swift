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
        // 必ず1つ目のidは0, TabView のタグに使われる
        .init(id: 0, title: "毎日のコーデを撮影", description: "家を出る前 や 明日のコーデを考える時\n 鏡に映る**全身写真**を撮影", imageName: "onboarding1"),
        .init(id: 1, title: "AIがコーデをレビュー", description: "撮影したコーデをもとに\nAIが **あなただけ** のレビューをお届け", imageName: "onboarding2")
    ]
    @State private var selectedOnbordingIndex: Int = 0
    let closeButtonTapped: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            TabView(selection: $selectedOnbordingIndex) {
                ForEach(onbordingInfos, id: \.self) { onbordingInfo in
                    OnboardingCardView(onbordingInfo: onbordingInfo)
                        .tag(onbordingInfo.id)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height * 0.6)
            .animation(.easeInOut, value: selectedOnbordingIndex)

            TabIndexView(numberOfPages: onbordingInfos.count, currentIndex: selectedOnbordingIndex)
            NextButton()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func OnboardingCardView(onbordingInfo: OnboardingInfo) -> some View {
        VStack(spacing: 12) {
            Text("\(onbordingInfo.title)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .multilineTextAlignment(.center)

            // マークダウン形式で表示するために String.init() を使用
            Text(.init(onbordingInfo.description))
                .font(.system(size: 16))
                .foregroundStyle(.gray)
                .padding(.horizontal, 24)
                .multilineTextAlignment(.center)

//            Image(uiImage: uiImage)
            Image(onbordingInfo.imageName)
                .resizable()
                .frame(maxWidth: .infinity)
                .aspectRatio(contentMode: .fit)
                .padding(.top, 12)
        }
    }

    private func NextButton() -> some View {
        Button(action: {
            if selectedOnbordingIndex < onbordingInfos.count - 1 {
                selectedOnbordingIndex += 1
            } else {
                closeButtonTapped()
            }
        }) {
            Text(selectedOnbordingIndex < onbordingInfos.count - 1 ? "次へ" : "閉じる")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
        }
    }
}

#Preview {
    OnboardingView(closeButtonTapped: {})
}
