//
//  PartnerPattern3GrowthView.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  パターン③「育つ相棒」— 育成型
//
//  相棒との関係がレベルで可視化される。
//  クエスト（今日の1問・リアクション・投票）をこなすほど
//  相棒の理解度が育ち、できることが解放されていく。
//

import SwiftUI

struct PartnerPattern3GrowthView: View {
    @State private var viewModel = PartnerPattern3ViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("相棒の成長を確認中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let growth = viewModel.growth {
                ScrollView {
                    VStack(spacing: 28) {
                        gaugeSection(state: growth.state)

                        if let greeting = viewModel.greeting {
                            PartnerTalkBubble(text: greeting)
                        }

                        PartnerAdviceCard()

                        questsSection(quests: growth.quests)
                        levelsSection(levels: growth.levels, currentLevel: growth.state.level)
                        eventsSection(events: growth.recent_events)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.white)
        .task {
            if viewModel.growth == nil {
                await viewModel.load()
            }
        }
    }

    // MARK: - 円形ゲージ + アバター

    private func gaugeSection(state: PartnerState) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: viewModel.animatedGauge)
                    .stroke(
                        AngularGradient(
                            colors: [.pink.opacity(0.6), .pink, .purple.opacity(0.8)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    PartnerIconImage(size: 88)

                    Text("\(state.understanding_pct)%")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)

                    Text("あなたへの理解度")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 210, height: 210)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text("Lv.\(state.level)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.pink)
                        .clipShape(Capsule())

                    Text(state.level_name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }

                if state.exp_to_next > 0 {
                    Text("つぎのレベルまで あと \(state.exp_to_next)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                } else {
                    Text("さいこうの相棒になれたよ 🤍")
                        .font(.system(size: 12))
                        .foregroundColor(.pink)
                }

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("\(state.streak_days)日連続で会えてる")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.top, 2)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                viewModel.animatedGauge = CGFloat(state.understanding_pct) / 100
            }
        }
    }

    // MARK: - 今日のクエスト

    private func questsSection(quests: [PartnerQuest]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("今日のクエスト", icon: "checklist")

            VStack(spacing: 10) {
                ForEach(quests) { quest in
                    HStack(spacing: 12) {
                        Image(systemName: quest.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(quest.done ? .green : .gray.opacity(0.4))

                        Text(quest.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(quest.done ? .gray : .black)
                            .strikethrough(quest.done, color: .gray)

                        Spacer()

                        Text("+\(quest.exp)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(quest.done ? .gray.opacity(0.5) : .pink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(quest.done ? Color.green.opacity(0.06) : Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - 解放ロードマップ

    private func levelsSection(levels: [PartnerLevelInfo], currentLevel: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("相棒ができるようになること", icon: "sparkles")

            VStack(spacing: 0) {
                ForEach(levels) { level in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(level.unlocked ? Color.pink.opacity(0.12) : Color.gray.opacity(0.08))
                                .frame(width: 38, height: 38)

                            Image(systemName: level.unlocked ? "heart.fill" : "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(level.unlocked ? .pink : .gray.opacity(0.5))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Lv.\(level.level) \(level.name)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(level.unlocked ? .black : .gray)

                                if level.level == currentLevel {
                                    Text("いまここ")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.pink)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(level.perk)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 10)

                    if level.level < levels.count {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 1)
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - 最近のできごと

    private func eventsSection(events: [PartnerExpEvent]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("ふたりのきろく", icon: "book.closed")

            if events.isEmpty {
                Text("これからいっぱい増えていくよ")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                        HStack {
                            Text(event.label)
                                .font(.system(size: 13))
                                .foregroundColor(.black)

                            Spacer()

                            Text("+\(event.exp)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.pink)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.pink)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class PartnerPattern3ViewModel {
    var growth: PartnerGrowthResponse?
    var greeting: String?
    var isLoading = false
    var animatedGauge: CGFloat = 0

    private let apiClient: PartnerClientProtocol

    init(apiClient: PartnerClientProtocol = FallbackPartnerClient()) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let userId = PartnerPatternUtility.userId

        async let growthTask = try? apiClient.getGrowth(userId: userId)
        async let homeTask = try? apiClient.getHome(userId: userId)

        if case .success(let response) = await growthTask {
            growth = response
        }
        if case .success(let response) = await homeTask {
            greeting = response.greeting
        }
    }
}

#Preview {
    PartnerPattern3GrowthView()
}
