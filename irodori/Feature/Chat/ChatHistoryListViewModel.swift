//
//  ChatHistoryListViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2026/05/01.
//

import Foundation

@MainActor @Observable final class ChatHistoryListViewModel {
    var conversations: [ConversationResponse] = []
    var isLoading: Bool = false

    private let apiClient: ChatClientProtocol
    private let userId: String

    init(apiClient: ChatClientProtocol) {
        self.apiClient = apiClient
        self.userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
    }

    func onAppear() async {
        guard !userId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        guard let result = try? await apiClient.fetchConversations(userId: userId, limit: 30) else { return }
        if case .success(let list) = result {
            conversations = list
        }
    }
}
