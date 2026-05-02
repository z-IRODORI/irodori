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
            header

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
                                ForEach(viewModel.messages) { message in
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
        .background(Color.gray.opacity(0.04))
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.loadMessages(conversationId: conversationId) }
    }

    // MARK: - Subviews

    private var header: some View {
        ZStack {
            Text("コーデ相談の履歴")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
            HStack {
                Button(action: { path.removeLast() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.black)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.white)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var continueButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: { path.append(.generalChat) }) {
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
