//
//  ProfileViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/04.
//

import SwiftUI
import Observation
import UIKit

@MainActor
@Observable
final class ProfileViewModel {
    var selectedCategory: ClothingCategory = .all
    var closetItems: [ClosetItem] = []
    var isLoading = false
    var errorMessage: String?
    var profileInfo: ProfileInfo?
    var isLoadingProfile = false

    private let closetClient: ClosetClientProtocol

    init(closetClient: ClosetClientProtocol = ClosetClient()) {
        self.closetClient = closetClient
        loadProfileFromDefaults()
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

    // MARK: - Profile Management

    private func loadProfileFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKey.profileInfo.rawValue) else {
            // プロフィール情報がない場合はデフォルト値を作成
            createDefaultProfile()
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            profileInfo = try decoder.decode(ProfileInfo.self, from: data)
        } catch {
            print("Failed to decode profile info: \(error)")
            createDefaultProfile()
        }
    }

    private func createDefaultProfile() {
        guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue),
              let userData = UserDefaults.standard.data(forKey: UserDefaultsKey.userInfo.rawValue),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            return
        }

        let profile = ProfileInfo(
            id: uid,
            username: user.username,
            displayName: user.username,
            profileImageUrl: nil,
            createdAt: Date(),
            lastLoginAt: nil
        )

        profileInfo = profile
        saveProfile(profile)
    }

    func saveProfile(_ profile: ProfileInfo) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.profileInfo.rawValue)
            profileInfo = profile
        } catch {
            print("Failed to save profile info: \(error)")
        }
    }

    func updateLastLoginAt() {
        guard var profile = profileInfo else { return }
        profile.lastLoginAt = Date()
        saveProfile(profile)
    }

    func updateProfileImage(url: String) {
        guard var profile = profileInfo else { return }
        profile.profileImageUrl = url
        saveProfile(profile)
    }

    func updateDisplayName(_ displayName: String) {
        guard var profile = profileInfo else { return }
        profile.displayName = displayName
        saveProfile(profile)
    }

    func uploadProfileImage(_ image: UIImage) async {
        // TODO: 実際のAPIを使用して画像をアップロードする
        // 今はダミー実装として、画像をローカルに保存する
        isLoadingProfile = true

        // ダミー実装: 画像をアプリのドキュメントディレクトリに保存
        if let data = image.jpegData(compressionQuality: 0.8) {
            let filename = "profile_\(UUID().uuidString).jpg"
            if let url = saveImageToDocuments(data: data, filename: filename) {
                updateProfileImage(url: url.absoluteString)
            }
        }

        isLoadingProfile = false
    }

    private func saveImageToDocuments(data: Data, filename: String) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
}
