//
//  GeneralChatViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2026/05/01.
//

import Foundation
import Observation

@MainActor
@Observable
final class GeneralChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var isLoadingHistory: Bool = false

    private var conversationId: String?
    private let userId: String
    private let apiClient: ChatClientProtocol

    init(apiClient: ChatClientProtocol) {
        self.userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        self.apiClient = apiClient
        self.conversationId = UserDefaults.standard.string(forKey: UserDefaultsKey.generalChatConversationId.rawValue)
    }

    func onAppear() async {
        guard !userId.isEmpty else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        if conversationId == nil {
            await createConversation()
        }

        guard let convId = conversationId else { return }
        await loadHistory(conversationId: convId)
    }

    private func createConversation() async {
        let result = try? await apiClient.createConversation(
            userId: userId,
            type: "general",
            coordinateId: nil
        )
        if case .success(let conv) = result {
            conversationId = conv.conversation_id
            UserDefaults.standard.set(conv.conversation_id, forKey: UserDefaultsKey.generalChatConversationId.rawValue)
        }
    }

    private func loadHistory(conversationId: String) async {
        let result = try? await apiClient.fetchMessages(
            conversationId: conversationId,
            userId: userId,
            limit: 50
        )
        if case .success(let historyResponse) = result {
            messages = historyResponse.messages.map { $0.asChatMessage }
        }
    }

    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !userId.isEmpty, let convId = conversationId else { return }

        let messageText = inputText
        inputText = ""

        let userMessage = ChatMessage(text: messageText, isUser: true)
        messages.append(userMessage)

        isLoading = true
        defer { isLoading = false }

        var genderString = UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        if genderString == nil,
           let userData = UserDefaults.standard.data(forKey: UserDefaultsKey.userInfo.rawValue),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            genderString = user.gender.apiValue
        }
        let gender = Gender.fromWithDefault(genderString, default: .other)

        let request = ChatWithHistoryRequest(
            user_id: userId,
            question: messageText + "\n# 制約\n- 出力は300文字以内で",
            gender: gender,
            image_base64: nil
        )

        do {
            let response = try await apiClient.postWithHistory(conversationId: convId, request: request)
            if case .success(let result) = response {
                messages.append(result.ai_message.asChatMessage)
            }
        } catch {}
    }

    func addSuggestedQuestion(_ question: String) {
        inputText = question
    }
}
