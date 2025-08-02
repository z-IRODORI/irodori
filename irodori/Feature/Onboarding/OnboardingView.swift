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
    var imageName: String
}

struct OnboardingView: View {
    let onbordingInfos: [OnboardingInfo] = [
        .init(id: 0, title: "はじめまして", imageName: "square"),
        .init(id: 1, title: "毎日のコーデを撮影します", imageName: "square"),
        .init(id: 2, title: "AIがコーデをレビューしてくれます", imageName: "square"),
        .init(id: 3, title: "カレンダーでいつでも見返せます", imageName: "square")
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
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height * 0.65)
            .animation(.easeInOut, value: selectedOnbordingIndex)

            TabIndexView(numberOfPages: onbordingInfos.count, currentIndex: selectedOnbordingIndex)
            NextButton()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func OnboardingCardView(onbordingInfo: OnboardingInfo) -> some View {
        VStack {
            Text("\(onbordingInfo.title)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)

//            Image(uiImage: uiImage)
            Image(onbordingInfo.imageName)
                .resizable()
                .frame(maxWidth: .infinity)
                .aspectRatio(contentMode: .fit)
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
