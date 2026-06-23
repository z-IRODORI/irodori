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
    @State private var showAllEvents = false

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

                Text("これまで \(state.level)日 いっしょにいるよ")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

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

    // MARK: - ふたりのきろく

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
                    ForEach(Array(events.prefix(10).enumerated()), id: \.offset) { _, event in
                        eventRow(event)
                    }
                }

                if events.count > 10 {
                    Button {
                        Haptic.impact(.soft)
                        showAllEvents = true
                    } label: {
                        Text("すべてを見る（\(events.count)件）")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.pink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.pink.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showAllEvents) {
            allEventsSheet(events: events)
        }
    }

    // ふたりのきろくの1行（活動ログ。exp は出さず、種別アイコンで表す）
    private func eventRow(_ event: PartnerExpEvent) -> some View {
        HStack(spacing: 10) {
            Image(systemName: event.kind == "coordinate" ? "tshirt.fill" : "heart.fill")
                .font(.system(size: 12))
                .foregroundColor(event.kind == "coordinate" ? .blue : .pink)

            Text(event.label)
                .font(.system(size: 13))
                .foregroundColor(.black)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // 全件をスクロールで見るシート
    private func allEventsSheet(events: [PartnerExpEvent]) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                        eventRow(event)
                    }
                }
                .padding(20)
            }
            .navigationTitle("ふたりのきろく")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { showAllEvents = false }
                        .foregroundColor(.black)
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
