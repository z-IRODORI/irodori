//
//  ChatHistoryDetailView.swift
//  irodori
//
//  Created by yuki.hamada on 2026/05/01.
//

import SwiftUI

struct ChatHistoryDetailView: View {
    @Binding var path: [ViewType]
    let conversationId: String
    @State var viewModel: ChatHistoryDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(24)
                        } else if viewModel.messages.isEmpty {
                            Text("メッセージがありません")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(24)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                    let showDate = index == 0 || !Calendar.current.isDate(message.timestamp, inSameDayAs: viewModel.messages[index - 1].timestamp)
                                    if showDate {
                                        ChatDateSeparatorView(date: message.timestamp)
                                    }
                                    GeneralChatBubbleView(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.vertical, 16)
                        }

                        Color.clear.frame(height: 20).id("bottom")
                    }
                }
                .onAppear {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            continueButton
        }
        .background(.white)
        .navigationTitle("コーデ相談の履歴")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadMessages(conversationId: conversationId) }
    }

    // MARK: - Subviews

    private var continueButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: { path.append(.generalChat(conversationId: nil)) }) {
                HStack(spacing: 8) {
                    PartnerIconImage(size: 24)
                    Text("この相棒に質問する")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }
}

#Preview {
    NavigationStack {
        ChatHistoryDetailView(
            path: .constant([.chatHistoryDetail(conversationId: "mock-coord-1")]),
            conversationId: "mock-coord-1",
            viewModel: ChatHistoryDetailViewModel(apiClient: MockChatClient())
        )
    }
}
