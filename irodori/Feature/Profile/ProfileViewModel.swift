//
//  ProfileViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/04.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    var selectedCategory: ClothingCategory = .all
    var closetItems: [ClosetItem] = []
    var isLoading = false
    var errorMessage: String?

    private let closetClient: ClosetClientProtocol

    init(closetClient: ClosetClientProtocol = ClosetClient()) {
        self.closetClient = closetClient
    }

    // フィルタリング済みアイテム
    var filteredItems: [ClosetItem] {
        let itemsWithImage = closetItems.filter { item in
            guard let imageUrl = item.image_url, !imageUrl.isEmpty else {
                return false
            }
            return true
        }

        if selectedCategory == .all {
            return itemsWithImage
        }
        return itemsWithImage.filter { $0.clothingCategory == selectedCategory }
    }

    func loadItems() async {
        guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
            errorMessage = "ユーザー情報が取得できませんでした"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await closetClient.get(uid: uid, itemType: nil)

            switch result {
            case .success(let response):
                closetItems = response.items
            case .failure(let error):
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = "通信エラーが発生しました"
        }

        isLoading = false
    }
}
