//
//  GeneralChatView.swift
//  irodori
//
//  Created by yuki.hamada on 2026/05/01.
//

import SwiftUI

struct GeneralChatView: View {
    @Binding var path: [ViewType]
    @State var viewModel: GeneralChatViewModel

    private let suggestedQuestions: [String] = [
        "今日の気分に合う服は？",
        "コーデの悩みを聞いて",
        "定番アイテムを教えて",
        "季節の変わり目コーデは？",
        "シンプルに見えるコツは？"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        partnerIntro
                            .padding(.top, 24)
                            .padding(.bottom, 8)

                        if viewModel.isLoadingHistory {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(viewModel.messages) { message in
                                    GeneralChatBubbleView(message: message)
                                        .id(message.id)
                                }

                                if viewModel.isLoading {
                                    HStack {
                                        PartnerIconImage(size: 40)
                                        HStack(spacing: 6) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                                .scaleEffect(0.8)
                                            Text("考え中...")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        Spacer(minLength: 60)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(.vertical, 12)
                        }

                        Color.clear.frame(height: 20).id("bottom")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            bottomBar
        }
        .background(.white)
        .navigationTitle("相棒に質問する")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        if viewModel.messages.isEmpty {
                            Task { await viewModel.startNewConversation() }
                        } else {
                            viewModel.showNewConversationAlert = true
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.black)
                    }
                    Button(action: { path.append(.chatHistoryList) }) {
                        Image(systemName: "clock")
                            .foregroundStyle(.black)
                    }
                }
            }
        }
        .alert("新しい会話を始めますか？", isPresented: $viewModel.showNewConversationAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("始める") {
                Task { await viewModel.startNewConversation() }
            }
        } message: {
            Text("現在の会話は履歴に保存されます。")
        }
        .task { await viewModel.onAppear() }
    }

    // MARK: - Subviews

    private var partnerIntro: some View {
        HStack(spacing: 10) {
            PartnerIconImage(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("相棒")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                Text("ファッションについて何でも相談してくださいね。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            GeneralSuggestedQuestionsView(
                questions: suggestedQuestions,
                onQuestionTapped: { viewModel.addSuggestedQuestion($0) }
            )

            GeneralChatInputView(
                text: $viewModel.inputText,
                onSend: { Task { await viewModel.sendMessage() } }
            )
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - GeneralChatBubbleView（白黒配色）

struct GeneralChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                PartnerIconImage(size: 40)
            }

            Text(.init(message.text))
                .font(.system(size: 14))
                .foregroundStyle(message.isUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isUser ? Color.black : Color.gray.opacity(0.1))
                )
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser {
                Spacer(minLength: 30)
            }
        }
        .padding(.trailing, 16)
        .padding(.leading, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - GeneralSuggestedQuestionsView（白黒配色）

struct GeneralSuggestedQuestionsView: View {
    let questions: [String]
    let onQuestionTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.black)
                Text("質問候補")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(questions, id: \.self) { question in
                        Button(action: { onQuestionTapped(question) }) {
                            Text(question)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.black.opacity(0.15), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 38)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color.gray.opacity(0.03))
    }
}

// MARK: - GeneralChatInputView（白黒配色）

struct GeneralChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("メッセージを入力", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .focused($isFocused)
                .onSubmit { onSend() }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(24)

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(text.isEmpty ? Color.gray.opacity(0.4) : Color.black)
                    .clipShape(Circle())
            }
            .disabled(text.isEmpty)
            .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    NavigationStack {
        GeneralChatView(
            path: .constant([]),
            viewModel: GeneralChatViewModel(apiClient: MockChatClient(), conversationId: nil)
        )
    }
}
