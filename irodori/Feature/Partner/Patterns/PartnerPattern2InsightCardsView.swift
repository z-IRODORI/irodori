//
//  PartnerPattern2InsightCardsView.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  パターン②「相棒の気づき」— インサイトカード型
//
//  相棒があなたのデータから見つけた「気づき」をカードで1枚ずつ受け取る。
//  「当たってる！/ ちがうかも / もっと教えて」のリアクションが
//  相棒の理解を補正するヒューマンインザループ。
//

import SwiftUI

struct PartnerPattern2InsightCardsView: View {
    @State private var viewModel = PartnerPattern2ViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("気づきを集めています...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    headerSection

                    if viewModel.isFinished {
                        finishedSection
                    } else {
                        cardStackSection
                        reactionSection
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white)
        .partnerExpToast($viewModel.expGained)
        .task {
            if viewModel.cards.isEmpty && !viewModel.isFinished {
                await viewModel.load()
            }
        }
    }

    // MARK: - ヘッダー

    private var headerSection: some View {
        VStack(spacing: 12) {
            PartnerTalkBubble(text: viewModel.partnerMessage)

            if let state = viewModel.state {
                HStack {
                    PartnerUnderstandingChip(state: state)
                    Spacer()
                    if !viewModel.isFinished {
                        Text("のこり \(viewModel.cards.count) 枚")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.partnerMessage)
    }

    // MARK: - カードスタック

    private var cardStackSection: some View {
        ZStack {
            ForEach(Array(viewModel.cards.prefix(3).enumerated().reversed()), id: \.element.id) { index, card in
                insightCard(card)
                    .offset(y: CGFloat(index) * 10)
                    .scaleEffect(1 - CGFloat(index) * 0.04)
                    .opacity(index == 0 ? 1 : 0.6)
                    .zIndex(Double(3 - index))
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.cards)
    }

    private func insightCard(_ card: PartnerInsightCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(card.emoji)
                    .font(.system(size: 40))

                Spacer()

                Text(patternLabel(card.pattern))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(patternColor(card.pattern))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(patternColor(card.pattern).opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(card.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.black)

            Text(card.body)
                .font(.system(size: 15))
                .foregroundColor(.black)
                .lineSpacing(6)

            Spacer(minLength: 0)

            if let hint = card.data_hint {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                    Text(hint)
                        .font(.system(size: 11))
                }
                .foregroundColor(.gray)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(patternColor(card.pattern).opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    private func patternColor(_ pattern: String) -> Color {
        switch pattern {
        case "ratio": return .blue
        case "celebration": return .pink
        case "question": return .purple
        case "future": return .orange
        case "discovery": return .green
        case "comparison": return .teal
        default: return .gray
        }
    }

    private func patternLabel(_ pattern: String) -> String {
        switch pattern {
        case "ratio": return "みつけた傾向"
        case "celebration": return "おめでとう"
        case "question": return "ききたいこと"
        case "future": return "ちょっと先の話"
        case "discovery": return "新発見"
        case "comparison": return "へんか"
        default: return "気づき"
        }
    }

    // MARK: - リアクション

    private var reactionSection: some View {
        HStack(spacing: 10) {
            reactionButton(title: "当たってる！", emoji: "🎯", reaction: "accurate", color: .pink)
            reactionButton(title: "ちがうかも", emoji: "🤔", reaction: "not_quite", color: .gray)
            reactionButton(title: "もっと教えて", emoji: "👂", reaction: "tell_me_more", color: .blue)
        }
    }

    private func reactionButton(title: String, emoji: String, reaction: String, color: Color) -> some View {
        Button {
            Haptic.impact(.light)
            Task { await viewModel.react(reaction) }
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color == .gray ? .gray : color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(viewModel.isReacting)
    }

    // MARK: - 完了

    private var finishedSection: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("✨")
                .font(.system(size: 56))

            Text("今日の気づきはここまで")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.black)

            Text("あなたの反応のおかげで、相棒の目がまた少し良くなったよ。\n明日も新しい気づきを持ってくるね。")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(5)

            if let state = viewModel.state {
                PartnerUnderstandingBar(state: state)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class PartnerPattern2ViewModel {
    var cards: [PartnerInsightCard] = []
    var state: PartnerState?
    var partnerMessage = "今日の気づき、持ってきたよ。正直なリアクション、待ってるね 👀"
    var expGained: Int?
    var isLoading = false
    var isReacting = false
    var isFinished = false

    private let apiClient: PartnerClientProtocol

    init(apiClient: PartnerClientProtocol = FallbackPartnerClient()) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let userId = PartnerPatternUtility.userId

        async let homeTask = try? apiClient.getHome(userId: userId)
        async let cardsTask = try? apiClient.getInsightCards(userId: userId, limit: 3)

        if case .success(let response) = await homeTask {
            state = response.state
        }
        if case .success(let response) = await cardsTask {
            cards = response.cards
            isFinished = cards.isEmpty
        }
    }

    func react(_ reaction: String) async {
        guard let card = cards.first, !isReacting else { return }
        isReacting = true
        defer { isReacting = false }

        do {
            let result = try await apiClient.reactToCard(
                userId: PartnerPatternUtility.userId,
                cardId: card.id,
                cardTitle: card.title,
                reaction: reaction
            )
            if case .success(let response) = result {
                Haptic.notify(.success)
                withAnimation {
                    partnerMessage = response.reply
                    expGained = response.exp_gained
                    state = response.state
                    cards.removeFirst()
                    if cards.isEmpty {
                        isFinished = true
                    }
                }
            }
        } catch {
            ToastManager.shared.show("送信に失敗しました")
        }
    }
}

#Preview {
    PartnerPattern2InsightCardsView()
}
