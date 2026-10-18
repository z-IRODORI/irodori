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
    /// 「相棒に相談」タップ時 (チャットへの遷移は呼び出し元が担う)。nil ならボタン非表示
    var onConsultTap: (() -> Void)? = nil
    /// 「4つの質問」やり直しタップ時
    var onRetakeOnboarding: (() -> Void)? = nil
    @State private var viewModel = PartnerPattern3ViewModel()
    @State private var showAllEvents = false

    private var persistedOnboarding: PartnerOnboardingResponse? {
        PartnerOnboardingFlowViewModel.loadPersistedResponse()
    }

    private var partnerTypeName: String {
        if let t = viewModel.partnerHome?.type_name, !t.isEmpty { return t }
        if let t = persistedOnboarding?.type_name, !t.isEmpty { return t }
        if let saved = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerImage.rawValue), !saved.isEmpty {
            return saved
        }
        return "ナチュラル・パートナー"
    }

    private var partnerSubtitle: String {
        if let sub = viewModel.partnerHome?.partner_subtitle, !sub.isEmpty { return sub }
        if let sub = persistedOnboarding?.partner_subtitle, !sub.isEmpty { return sub }
        return "あなたの好みと予定に寄り添うスタイリスト"
    }

    private var displayTraits: [PartnerOnboardingTrait] {
        if let traits = viewModel.partnerHome?.traits, !traits.isEmpty { return traits }
        if let traits = persistedOnboarding?.traits, !traits.isEmpty { return traits }
        return []
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("相棒を読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let growth = viewModel.growth {
                ScrollView {
                    VStack(spacing: 24) {
                        gaugeSection(state: growth.state)

                        if let greeting = viewModel.greeting {
                            PartnerTalkBubble(text: greeting)
                        }

                        traitsSection

                        PartnerAdviceCard()

                        eventsSection(events: growth.recent_events)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 80)
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

    // MARK: - 相棒プロフィール + 理解度リング

    private func gaugeSection(state: PartnerState) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: viewModel.animatedGauge)
                    .stroke(
                        Color.black,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    PartnerIconImage(size: 84)

                    Text("理解度 \(state.understanding_pct)%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            .frame(width: 176, height: 176)

            VStack(spacing: 5) {
                Text(partnerTypeName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                Text(partnerSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Label("\(state.level)日いっしょ", systemImage: "calendar")
                    if state.streak_days > 0 {
                        Label("\(state.streak_days)日連続", systemImage: "sparkles")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }

            if let onConsultTap {
                Button {
                    Haptic.impact(.soft)
                    onConsultTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("相棒にチャットで相談する")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                viewModel.animatedGauge = CGFloat(state.understanding_pct) / 100
            }
        }
    }

    // MARK: - 相棒が覚えている4つの特徴

    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("相棒が覚えているあなたのこと", icon: "person.text.rectangle")
                Spacer()
                if let onRetakeOnboarding {
                    Button {
                        Haptic.impact(.soft)
                        onRetakeOnboarding()
                    } label: {
                        Text("変更する")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if displayTraits.isEmpty {
                Button {
                    onRetakeOnboarding?()
                } label: {
                    HStack {
                        Text("4つの質問に答えて、相棒にあなたの特徴を教える")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.black)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(displayTraits) { trait in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trait.axis_label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(trait.label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - ふたりのきろく

    private func eventsSection(events: [PartnerExpEvent]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("ふたりのきろく", icon: "book.closed")

            if events.isEmpty {
                Text("コーデを選んだり登録すると、ここに記録が増えていくよ")
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
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.08))
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
            Image(systemName: event.kind == "coordinate" ? "tshirt.fill" : "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.75))

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
                .foregroundColor(.black)

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
    var partnerHome: PartnerHomeResponse?
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
            partnerHome = response
            greeting = response.greeting
        }
    }
}

#Preview {
    PartnerPattern3GrowthView()
}
