//
//  CoordinateChatRepository.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

protocol CoordinateChatRepositoryProtocol {
    func saveCoordinateChat(_ coordinateChat: CoordinateChat)
    func loadCoordinateChat(coordinateId: String) -> CoordinateChat?
    func addMessageToCoordinate(coordinateId: String, message: ChatMessage)
    func clearCoordinateChat(coordinateId: String)
    func getAllCoordinateChats() -> [CoordinateChat]
    func createCoordinateChat(coordinateId: String, coordinateImageName: String) -> CoordinateChat
}

final class CoordinateChatRepository: CoordinateChatRepositoryProtocol {
    private let userDefaultsManager: UserDefaultsManagerProtocol
    
    init(userDefaultsManager: UserDefaultsManagerProtocol = UserDefaultsManager()) {
        self.userDefaultsManager = userDefaultsManager
    }
    
    func saveCoordinateChat(_ coordinateChat: CoordinateChat) {
        var allChats = getAllCoordinateChats()
        
        // 既存のチャットを更新または新規追加
        if let index = allChats.firstIndex(where: { $0.coordinateId == coordinateChat.coordinateId }) {
            allChats[index] = coordinateChat
        } else {
            allChats.append(coordinateChat)
        }
        
        userDefaultsManager.save(allChats, forKey: .coordinateChats)
    }
    
    func loadCoordinateChat(coordinateId: String) -> CoordinateChat? {
        let allChats = getAllCoordinateChats()
        return allChats.first { $0.coordinateId == coordinateId }
    }
    
    func addMessageToCoordinate(coordinateId: String, message: ChatMessage) {
        guard var coordinateChat = loadCoordinateChat(coordinateId: coordinateId) else { return }
        
        coordinateChat.messages.append(message)
        coordinateChat.lastUpdated = Date()
        saveCoordinateChat(coordinateChat)
    }
    
    func clearCoordinateChat(coordinateId: String) {
        var allChats = getAllCoordinateChats()
        allChats.removeAll { $0.coordinateId == coordinateId }
        userDefaultsManager.save(allChats, forKey: .coordinateChats)
    }
    
    func getAllCoordinateChats() -> [CoordinateChat] {
        return userDefaultsManager.load([CoordinateChat].self, forKey: .coordinateChats) ?? []
    }
    
    func createCoordinateChat(coordinateId: String, coordinateImageName: String) -> CoordinateChat {
        let coordinateChat = CoordinateChat(coordinateId: coordinateId, coordinateImageName: coordinateImageName)
        
        // ウェルカムメッセージを追加
        let welcomeMessage = ChatMessage(text: "こんにちは！このコーディネートについて何でも相談してくださいね。", isUser: false)
        var chatWithMessage = coordinateChat
        chatWithMessage.messages.append(welcomeMessage)
        
        saveCoordinateChat(chatWithMessage)
        return chatWithMessage
    }
}