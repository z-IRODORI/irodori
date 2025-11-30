//
//  ChatViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var coordinateChat: CoordinateChat?
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    
    let coordinateId: String
    let coordinateImageName: String
    private let repository: CoordinateChatRepositoryProtocol
    
    var messages: [ChatMessage] {
        coordinateChat?.messages ?? []
    }
    
    init(
        coordinateId: String,
        coordinateImageName: String,
        repository: CoordinateChatRepositoryProtocol = CoordinateChatRepository()
    ) {
        self.coordinateId = coordinateId
        self.coordinateImageName = coordinateImageName
        self.repository = repository
    }
    
    func loadCoordinateChat() {
        if let existingChat = repository.loadCoordinateChat(coordinateId: coordinateId) {
            coordinateChat = existingChat
        } else {
            // 新しいコーディネートチャットを作成
            coordinateChat = repository.createCoordinateChat(
                coordinateId: coordinateId,
                coordinateImageName: coordinateImageName
            )
        }
    }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var currentCoordinateChat = coordinateChat else { return }
        
        let messageText = inputText
        inputText = ""
        
        // ユーザーメッセージを追加
        let userMessage = ChatMessage(text: messageText, isUser: true)
        addMessage(userMessage, to: &currentCoordinateChat)
        
        // AIレスポンスを生成（模擬実装）
        generateAIResponse(for: messageText)
    }
    
    func addSuggestedQuestion(_ question: String) {
        inputText = question
    }
    
    private func addMessage(_ message: ChatMessage, to coordinateChat: inout CoordinateChat) {
        coordinateChat.messages.append(message)
        coordinateChat.lastUpdated = Date()
        
        self.coordinateChat = coordinateChat
        repository.addMessageToCoordinate(coordinateId: coordinateId, message: message)
    }
    
    private func generateAIResponse(for userMessage: String) {
        isLoading = true
        
        // 実際の実装ではここでAI APIを呼び出す
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待機
            
            await MainActor.run {
                guard var currentCoordinateChat = coordinateChat else {
                    isLoading = false
                    return
                }
                
                let aiResponse = ChatMessage(
                    text: generateContextualResponse(for: userMessage),
                    isUser: false
                )
                
                addMessage(aiResponse, to: &currentCoordinateChat)
                isLoading = false
            }
        }
    }
    
    private func generateContextualResponse(for userMessage: String) -> String {
        // 簡単なルールベースレスポンス生成
        let message = userMessage.lowercased()
        
        if message.contains("色") || message.contains("カラー") {
            return "色の組み合わせがとても素敵ですね！この配色は季節感も表現できていて、バランスが取れています。"
        } else if message.contains("カジュアル") {
            return "カジュアルなスタイルにするなら、アクセサリーを少し控えめにしたり、よりリラックスした素材のアイテムを取り入れてみてはいかがでしょうか。"
        } else if message.contains("アイテム") || message.contains("追加") {
            return "このコーディネートにはシンプルなアクセサリーや小物を追加すると、より洗練された印象になると思います。"
        } else if message.contains("季節") {
            return "季節にとてもよく合ったコーディネートですね！この時期にぴったりの装いだと思います。"
        } else if message.contains("場面") || message.contains("シーン") {
            return "このスタイルは様々な場面で活用できそうですね。カジュアルからセミフォーマルまで対応できる万能なコーディネートです。"
        } else {
            return "なるほど、いいアイデアですね！そのアプローチでコーディネートをより魅力的にできると思います。"
        }
    }
    
    func clearChat() {
        repository.clearCoordinateChat(coordinateId: coordinateId)
        coordinateChat = repository.createCoordinateChat(
            coordinateId: coordinateId,
            coordinateImageName: coordinateImageName
        )
    }
}
