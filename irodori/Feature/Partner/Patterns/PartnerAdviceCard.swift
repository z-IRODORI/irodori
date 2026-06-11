//
//  PartnerAdviceCard.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  「相棒からあなたへ」カード — 5パターン共通の追加要素。
//
//  ① 理解: あなたをこう見てる（根拠つき）
//  ② 提案: だから、こうしてみない？（理由つきで納得できる）
//  ③ 発見: それとね、こんな発見があった（本人も気づいていない一面）
//
//  の3段構成で、最後に「やってみる / 参考になった / 今はいいかな」の
//  フィードバックが相棒の学習に返るヒューマンインザループ。
//  自己完結コンポーネントなので、どのパターンにも1行で埋め込める。
//

import SwiftUI

struct PartnerAdviceCard: View {
    @State private var viewModel = PartnerAdviceCardViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if let advice = viewModel.advice {
                stepsTimeline(advice: advice)

                if let hint = advice.evidence_hint {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text(hint)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.gray)
                }

                Divider()

                feedbackArea
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.35), .purple.opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
        .task {
            if viewModel.advice == nil {
                await viewModel.load()
            }
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(spacing: 10) {
            PartnerIconImage(size: 30)

            Text("相棒からあなたへ")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            Spacer()

            Text("きょうのひとこと")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.pink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.pink.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: - 理解 → 提案 → 発見 のタイムライン

    private func stepsTimeline(advice: PartnerAdvice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            adviceStep(
                icon: "eye.fill", color: .blue, label: "あなたのこと、見えてきた",
                text: advice.understanding, isLast: false
            )
            adviceStep(
                icon: "lightbulb.fill", color: .pink, label: "だから、ためしてほしい",
                text: advice.advice, isLast: false
            )
            adviceStep(
                icon: "sparkles", color: .orange, label: "それとね、発見があった",
                text: advice.discovery, isLast: true
            )
        }
    }

    private func adviceStep(icon: String, color: Color, label: String, text: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(color)
                }

                if !isLast {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)

                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .lineSpacing(4)
                    .padding(.bottom, isLast ? 0 : 18)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - フィードバック（HITL）

    private var feedbackArea: some View {
        Group {
            if let reply = viewModel.reply {
                HStack(alignment: .top, spacing: 8) {
                    PartnerIconImage(size: 24)

                    Text(reply)
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                        .lineSpacing(3)

                    Spacer()

                    if let exp = viewModel.expGained {
                        Text("+\(exp)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.pink)
                            .clipShape(Capsule())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                HStack(spacing: 8) {
                    feedbackButton(title: "やってみる", emoji: "💪", reaction: "try_it", color: .pink)
                    feedbackButton(title: "参考になった", emoji: "🤍", reaction: "helpful", color: .blue)
                    feedbackButton(title: "今はいいかな", emoji: "🌷", reaction: "not_for_me", color: .gray)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.reply)
    }

    private func feedbackButton(title: String, emoji: String, reaction: String, color: Color) -> some View {
        Button {
            Haptic.impact(.light)
            Task { await viewModel.sendFeedback(reaction) }
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color == .gray ? .gray : color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
        }
        .disabled(viewModel.isSending)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class PartnerAdviceCardViewModel {
    var advice: PartnerAdvice?
    var reply: String?
    var expGained: Int?
    var isLoading = false
    var isSending = false

    private let apiClient: PartnerClientProtocol

    init(apiClient: PartnerClientProtocol = FallbackPartnerClient()) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await apiClient.getAdvice(userId: PartnerPatternUtility.userId)
            if case .success(let response) = result {
                advice = response.advice
            }
        } catch {
            // 表示できない場合はカードごと非表示（advice == nil のまま）
        }
    }

    func sendFeedback(_ reaction: String) async {
        guard let advice, !isSending else { return }
        isSending = true
        defer { isSending = false }

        do {
            let result = try await apiClient.sendAdviceFeedback(
                userId: PartnerPatternUtility.userId,
                adviceId: advice.id,
                reaction: reaction
            )
            if case .success(let response) = result {
                Haptic.notify(.success)
                withAnimation {
                    reply = response.reply
                    expGained = response.exp_gained
                }
            }
        } catch {
            ToastManager.shared.show("送信に失敗しました")
        }
    }
}

#Preview {
    ScrollView {
        PartnerAdviceCard()
            .padding(20)
    }
}
