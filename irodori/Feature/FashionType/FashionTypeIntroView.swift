//
//  FashionTypeIntroView.swift
//  irodori
//

import SwiftUI

struct FashionTypeIntroView: View {
    @Binding var path: [ViewType]
    @State private var isScrolling = false

    private let previewImages = [
        "アヴァンギャルド・スター",
        "ソーシャル・アイコン",
        "クリーン・スタンダード",
        "ヴィンテージ・ミニマリスト",
        "トレンド・エディター",
        "モテ・プランナー",
        "オーセンティック・アーティスト",
        "ロイヤル・クラシック"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                imageCollage
                contentSection
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .navigationBarHidden(true)
    }

    // MARK: - Image Collage

    private var imageCollage: some View {
        let imageHeight = UIScreen.main.bounds.height * 0.25
        let imageWidth = imageHeight * 0.75
        let spacing: CGFloat = 4
        let totalWidth = CGFloat(previewImages.count) * (imageWidth + spacing)
        let loopedImages = previewImages + previewImages

        // Color.clear で幅をスクリーン幅に固定し、HStack をオーバーレイすることで
        // 巨大な HStack がレイアウト幅を押し広げないようにする
        return Color.clear
            .frame(height: imageHeight)
            .overlay(alignment: .leading) {
                HStack(spacing: spacing) {
                    ForEach(Array(loopedImages.enumerated()), id: \.offset) { _, name in
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageWidth, height: imageHeight)
                            .clipped()
                    }
                }
                .offset(x: isScrolling ? -totalWidth : 0)
                .animation(
                    .linear(duration: Double(previewImages.count) * 2)
                    .repeatForever(autoreverses: false),
                    value: isScrolling
                )
                .onAppear { isScrolling = true }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.clear, Color.white],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: imageHeight * 0.5)
            }
            .clipped()
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(spacing: 32) {
            titleSection
            featureCards
            ctaSection
        }
    }

    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("ファッションタイプ診断")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black)
                .clipShape(Capsule())

            Text("あなただけのスタイルを\n発見しよう")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)

            Text("全16タイプの中から、あなたのファッション個性を診断します")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    private var featureCards: some View {
        VStack(spacing: 16) {
            FeatureCard(
                iconName: "sparkles",
                iconColor: .pink,
                title: "ファッション個性を5軸で分析",
                description: "流行感度・自己表現・社会性・機能性・経済性の5つの視点から、16タイプの中であなたらしさを診断します。"
            )
            FeatureCard(
                iconName: "tshirt.fill",
                iconColor: Color(red: 0.3, green: 0.5, blue: 1.0),
                title: "IRODORIがあなたを理解する",
                description: "タイプをもとに、よりパーソナルなコーデ・アイテムを提案します。コーデ記録もあなたらしさが積み重なっていきます。"
            )
            FeatureCard(
                iconName: "checkmark.circle.fill",
                iconColor: Color(red: 0.2, green: 0.7, blue: 0.5),
                title: "「なんとなく違う」がなくなる",
                description: "自分のスタイルを知ることで、服選びの直感が磨かれます。毎日のコーデがもっと楽しくなります。"
            )
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 20) {
            Text("全10問 / 約2分で完了")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)

            Button(action: {
                path.append(.fashionType)
            }) {
                Text("診断を始める")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.black)
                    .cornerRadius(27)
            }
        }
    }
}

// MARK: - Feature Card Component

private struct FeatureCard: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.gray)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.gray.opacity(0.04))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var path: [ViewType] = []
    NavigationStack(path: $path) {
        FashionTypeIntroView(path: $path)
            .navigationDestination(for: ViewType.self) { viewType in
                switch viewType {
                case .fashionType:
                    FashionTypeView(path: $path, viewModel: FashionTypeViewModel())
                case .fashionTypeResult(let response):
                    FashionTypeResultView(path: $path, result: response)
                default:
                    EmptyView()
                }
            }
    }
}
