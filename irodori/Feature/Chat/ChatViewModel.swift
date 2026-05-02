//
//  ChatViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation
import Observation

struct CoordinateChat: Identifiable, Codable {
    let id: String
    let coordinateId: String
    let coordinateImageName: String
    var messages: [ChatMessage]
    let createdAt: Date
    var lastUpdated: Date
    var conversationId: String?  // Firestore conversation ID (nil = not yet synced)

    init(coordinateId: String, coordinateImageName: String) {
        self.id = UUID().uuidString
        self.coordinateId = coordinateId
        self.coordinateImageName = coordinateImageName
        self.messages = []
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.conversationId = nil
    }
}

@MainActor
@Observable
final class ChatViewModel {
    var coordinateChat: CoordinateChat = .init(coordinateId: "", coordinateImageName: "")
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    let coordinateId: String
    let coordinateImageBase64: String
    private let apiClient: ChatClientProtocol
    private let repository: CoordinateChatRepositoryProtocol
    private let userId: String

    init(
        coordinateId: String,
        coordinateImageBase64: String,
        apiClient: ChatClientProtocol,
        repository: CoordinateChatRepositoryProtocol
    ) {
        self.coordinateId = coordinateId
        self.coordinateImageBase64 = coordinateImageBase64
        self.apiClient = apiClient
        self.repository = repository
        self.userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
    }

    func loadCoordinateChat() {
        if let existingChat = repository.loadCoordinateChat(coordinateId: coordinateId) {
            coordinateChat = existingChat
        } else {
            coordinateChat = repository.createCoordinateChat(
                coordinateId: coordinateId,
                coordinateImageName: coordinateImageBase64
            )
        }

        // バックグラウンドで Firestore の会話 ID を取得・履歴をマージ
        Task { await syncWithRemote() }
    }

    private func syncWithRemote() async {
        guard !userId.isEmpty else { return }

        // conversationId がなければ Firestore に会話を作成
        if coordinateChat.conversationId == nil {
            let result = try? await apiClient.createConversation(
                userId: userId,
                type: "coordinate",
                coordinateId: coordinateId,
                forceNew: false
            )
            if case .success(let conv) = result {
                coordinateChat.conversationId = conv.conversation_id
                repository.saveCoordinateChat(coordinateChat)
            }
        }

        // 履歴を取得してローカルキャッシュとマージ
        guard let convId = coordinateChat.conversationId else { return }
        let histResult = try? await apiClient.fetchMessages(
            conversationId: convId,
            userId: userId,
            limit: 50
        )
        if case .success(let historyResponse) = histResult, !historyResponse.messages.isEmpty {
            let remoteMessages = historyResponse.messages.map { $0.asChatMessage }
            let localIds = Set(coordinateChat.messages.map { $0.id })
            let newMessages = remoteMessages.filter { !localIds.contains($0.id) }
            if !newMessages.isEmpty {
                coordinateChat.messages.append(contentsOf: newMessages)
                coordinateChat.messages.sort { $0.timestamp < $1.timestamp }
                repository.saveCoordinateChat(coordinateChat)
            }
        }
    }

    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let messageText = inputText
        inputText = ""

        let userMessage = ChatMessage(text: messageText, isUser: true)
        addMessageLocally(userMessage)

        await generateAIMessage(for: messageText)
    }

    func addSuggestedQuestion(_ question: String) {
        inputText = question
    }

    private func addMessageLocally(_ message: ChatMessage) {
        coordinateChat.messages.append(message)
        coordinateChat.lastUpdated = Date()
        repository.addMessageToCoordinate(coordinateId: coordinateId, message: message)
    }

    private func generateAIMessage(for userMessage: String) async {
        isLoading = true
        defer { isLoading = false }

        var genderString = UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        if genderString == nil,
           let userData = UserDefaults.standard.data(forKey: UserDefaultsKey.userInfo.rawValue),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            genderString = user.gender.apiValue
            UserDefaults.standard.set(genderString, forKey: UserDefaultsKey.gender.rawValue)
        }
        let gender = Gender.fromWithDefault(genderString, default: .other)

        // Firestore 経由で送信（conversationId あり）
        if let convId = coordinateChat.conversationId, !userId.isEmpty {
            let request = ChatWithHistoryRequest(
                user_id: userId,
                question: userMessage + "# 制約\n- 出力は300文字以内で",
                gender: gender,
                image_base64: coordinateImageBase64.isEmpty ? nil : coordinateImageBase64
            )
            do {
                let response = try await apiClient.postWithHistory(conversationId: convId, request: request)
                if case .success(let result) = response {
                    let aiMessage = result.ai_message.asChatMessage
                    addMessageLocally(aiMessage)
                    return
                }
            } catch {}
        }

        // フォールバック: 既存のステートレス API
        do {
            let response = try await apiClient.post(chatRequest: .init(
                question: userMessage + "# 制約\n- 出力は300文字以内で",
                gender: gender,
                image_base64: coordinateImageBase64
            ))
            if case .success(let result) = response {
                let aiMessage = ChatMessage(text: result.answer, isUser: false)
                addMessageLocally(aiMessage)
            }
        } catch {}
    }

    func clearChat() {
        repository.clearCoordinateChat(coordinateId: coordinateId)
        coordinateChat = repository.createCoordinateChat(
            coordinateId: coordinateId,
            coordinateImageName: coordinateImageBase64
        )
    }
}
