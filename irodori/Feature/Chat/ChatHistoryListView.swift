//
//  ChatHistoryListView.swift
//  irodori
//
//  Created by yuki.hamada on 2026/05/01.
//

import SwiftUI

struct ChatHistoryListView: View {
    @Binding var path: [ViewType]
    @State var viewModel: ChatHistoryListViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.conversations) { conv in
                            ConversationRowView(conversation: conv)
                                .onTapGesture { navigate(conv) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
            }
        }
        .background(.white)
        .navigationTitle("チャット履歴")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            PartnerIconImage(size: 64)
            Text("まだチャット履歴がありません")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("相棒に質問してみましょう")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation

    private func navigate(_ conv: ConversationResponse) {
        if conv.type == "general" {
            path.append(.generalChat(conversationId: conv.conversation_id))
        } else {
            path.append(.chatHistoryDetail(conversationId: conv.conversation_id))
        }
    }
}

// MARK: - ConversationRowView

private struct ConversationRowView: View {
    let conversation: ConversationResponse

    var body: some View {
        HStack(spacing: 12) {
            iconView
            centerContent
            Spacer(minLength: 0)
            trailingContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var iconView: some View {
        Group {
            if conversation.type == "general" {
                PartnerIconImage(size: 44)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.black)
                }
            }
        }
    }

    private var centerContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.type == "general" ? "ファッション相談" : "コーデ相談")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
            if let preview = conversation.last_message_preview, !preview.isEmpty {
                Text(preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(formattedDate)
                .font(.system(size: 11))
                .foregroundStyle(Color.gray.opacity(0.7))
        }
    }

    private var trailingContent: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(conversation.message_count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.black)
                .clipShape(Capsule())
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.gray.opacity(0.5))
        }
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: conversation.last_updated) {
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        return conversation.last_updated
    }
}

#Preview {
    NavigationStack {
        ChatHistoryListView(
            path: .constant([.chatHistoryList]),
            viewModel: ChatHistoryListViewModel(apiClient: MockChatClient())
        )
    }
    .environment(MainTabViewModel())
}
