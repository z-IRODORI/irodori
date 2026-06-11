//
//  PartnerPattern1DailyTalkView.swift
//  irodori
//
//  Created by Claude on 2026/06/11.
//
//  パターン①「朝の相棒」— デイリー対話型
//
//  毎日ひとこと挨拶 + 1日1問だけの軽い質問。
//  スキップしても歓迎される「責めない」設計で、
//  答えるたびに相棒の理解度が上がるヒューマンインザループ。
//

import SwiftUI

struct PartnerPattern1DailyTalkView: View {
    @State private var viewModel = PartnerPattern1ViewModel()
    @State private var freeText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("相棒を呼んでいます...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        greetingSection
                        statusSection
                        questionSection
                        PartnerAdviceCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Color.white)
        .partnerExpToast($viewModel.expGained)
        .task {
            if viewModel.home == nil {
                await viewModel.load()
            }
        }
    }

    // MARK: - あいさつ

    private var greetingSection: some View {
        VStack(spacing: 12) {
            if let home = viewModel.home {
                PartnerTalkBubble(text: home.greeting, subText: home.sub_greeting)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.easeOut(duration: 0.4), value: viewModel.home)
    }

    // MARK: - 状態（ストリーク + 理解度）

    private var statusSection: some View {
        Group {
            if let state = viewModel.home?.state {
                VStack(spacing: 14) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.orange)
                            Text("\(state.streak_days)日連続")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.black)
                        }

                        Spacer()

                        PartnerUnderstandingChip(state: state)
                    }

                    PartnerUnderstandingBar(state: state)
                }
                .padding(16)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - 今日の1問

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.pink)

                Text("今日の1問")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                Spacer()

                if let category = viewModel.question?.category {
                    Text(category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if let reaction = viewModel.reaction {
                // 回答後: 相棒のリアクション
                answeredView(reaction: reaction)
            } else if let question = viewModel.question {
                // 未回答: 質問と選択肢
                questionView(question: question)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.pink.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.reaction)
    }

    private func questionView(question: PartnerDailyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question.text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .lineSpacing(4)

            VStack(spacing: 10) {
                ForEach(question.choices, id: \.self) { choice in
                    Button {
                        Haptic.impact(.light)
                        Task { await viewModel.answer(choice: choice) }
                    } label: {
                        Text(choice)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.gray.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            if question.allows_free_text {
                HStack(spacing: 8) {
                    TextField("じぶんの言葉でこたえる", text: $freeText)
                        .font(.system(size: 14))
                        .focused($isTextFieldFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.gray.opacity(0.07))
                        .clipShape(Capsule())

                    Button {
                        guard !freeText.isEmpty else { return }
                        Haptic.impact(.light)
                        isTextFieldFocused = false
                        Task { await viewModel.answer(freeText: freeText) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(freeText.isEmpty ? .gray.opacity(0.4) : .pink)
                    }
                    .disabled(freeText.isEmpty)
                }
            }

            Button {
                Haptic.selection()
                Task { await viewModel.skip() }
            } label: {
                Text("今日はパスする 🌷")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 2)
        }
    }

    private func answeredView(reaction: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PartnerTalkBubble(text: reaction)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.green)

                Text("今日のおしゃべり完了。また明日ね")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class PartnerPattern1ViewModel {
    var home: PartnerHomeResponse?
    var question: PartnerDailyQuestion?
    var reaction: String?
    var expGained: Int?
    var isLoading = false

    private let apiClient: PartnerClientProtocol

    init(apiClient: PartnerClientProtocol = FallbackPartnerClient()) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let userId = PartnerPatternUtility.userId

        async let homeTask = try? apiClient.getHome(userId: userId)
        async let questionTask = try? apiClient.getDailyQuestion(userId: userId)

        if case .success(let response) = await homeTask {
            home = response
        }
        if case .success(let response) = await questionTask {
            question = response.question
            if response.answered_today {
                reaction = response.answered_reaction
            }
        }
    }

    func answer(choice: String? = nil, freeText: String? = nil) async {
        guard let question else { return }
        await send(questionId: question.id, choice: choice, freeText: freeText, skipped: false)
    }

    func skip() async {
        guard let question else { return }
        await send(questionId: question.id, choice: nil, freeText: nil, skipped: true)
    }

    private func send(questionId: String, choice: String?, freeText: String?, skipped: Bool) async {
        do {
            let result = try await apiClient.answerDailyQuestion(
                userId: PartnerPatternUtility.userId,
                questionId: questionId,
                choice: choice,
                freeText: freeText,
                skipped: skipped
            )
            if case .success(let response) = result {
                Haptic.notify(.success)
                withAnimation {
                    reaction = response.reaction
                    expGained = response.exp_gained
                }
                if var currentHome = home {
                    currentHome = PartnerHomeResponse(
                        status: currentHome.status,
                        user_id: currentHome.user_id,
                        greeting: currentHome.greeting,
                        sub_greeting: currentHome.sub_greeting,
                        state: response.state
                    )
                    home = currentHome
                }
            }
        } catch {
            ToastManager.shared.show("送信に失敗しました")
        }
    }
}

#Preview {
    PartnerPattern1DailyTalkView()
}
