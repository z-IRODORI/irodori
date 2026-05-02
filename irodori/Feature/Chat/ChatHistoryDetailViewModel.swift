//
//  ChatHistoryDetailViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2026/05/01.
//

import Foundation

@MainActor @Observable final class ChatHistoryDetailViewModel {
    var messages: [ChatMessage] = []
    var isLoading: Bool = false

    private let apiClient: ChatClientProtocol
    private let userId: String

    init(apiClient: ChatClientProtocol) {
        self.apiClient = apiClient
        self.userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
    }

    func loadMessages(conversationId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        guard let result = try? await apiClient.fetchMessages(
            conversationId: conversationId,
            userId: userId,
            limit: 50
        ) else { return }
        if case .success(let response) = result {
            messages = response.messages.map { $0.asChatMessage }
        }
    }
}
