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

    init(coordinateId: String, coordinateImageName: String) {
        self.id = UUID().uuidString
        self.coordinateId = coordinateId
        self.coordinateImageName = coordinateImageName
        self.messages = []
        self.createdAt = Date()
        self.lastUpdated = Date()
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
    private let apiClient: HomeClientProtocol
    private let repository: CoordinateChatRepositoryProtocol
    
    init(
        coordinateId: String,
        coordinateImageBase64: String,
        apiClient: HomeClientProtocol,
        repository: CoordinateChatRepositoryProtocol
    ) {
        self.coordinateId = coordinateId
        self.coordinateImageBase64 = coordinateImageBase64
        self.apiClient = apiClient
        self.repository = repository
    }
    
    func loadCoordinateChat() {
        if let existingChat = repository.loadCoordinateChat(coordinateId: coordinateId) {
            coordinateChat = existingChat
        } else {
            // 新しいコーディネートチャットを作成
            coordinateChat = repository.createCoordinateChat(
                coordinateId: coordinateId,
                coordinateImageName: coordinateImageBase64
            )
        }
    }
    
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let messageText = inputText
        inputText = ""
        
        // ユーザーメッセージを追加
        let userMessage = ChatMessage(text: messageText, isUser: true)
        addMessage(userMessage)

        await generateAIMessage(for: messageText)
    }
    
    func addSuggestedQuestion(_ question: String) {
        inputText = question
    }
    
    private func addMessage(_ message: ChatMessage) {
        coordinateChat.messages.append(message)
        coordinateChat.lastUpdated = Date()
        repository.addMessageToCoordinate(coordinateId: coordinateId, message: message)
    }
    
    private func generateAIMessage(for userMessage: String) async {
        isLoading = true
        // 実際の実装ではここでAI APIを呼び出す
        let gender = UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue) ?? "other"
        do {
            let response = try await apiClient.post(homeRequest: .init(question: userMessage + "# 制約\n- 出力は300文字以内で", gender: gender, image_base64: coordinateImageBase64))
            switch response {
            case .success(let result):
                let chatMessage = ChatMessage(text: result.answer, isUser: false)
                addMessage(chatMessage)
            case .failure(let error):
                break
            }
        } catch {
            print(error.localizedDescription)
        }
        isLoading = false
    }
    
    func clearChat() {
        repository.clearCoordinateChat(coordinateId: coordinateId)
        coordinateChat = repository.createCoordinateChat(
            coordinateId: coordinateId,
            coordinateImageName: coordinateImageBase64
        )
    }
}
