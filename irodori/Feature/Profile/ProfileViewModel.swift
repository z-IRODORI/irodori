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
    var selectedCategory: ClothingCategory = .tops
    var closetItems: [ClosetItem] = []
    var isLoading = false
    var profileInfo: ProfileInfo?
    var isLoadingProfile = false
    /// 登録済みの場所 (メイン先頭 + 追加)。プロフィールヘッダー表示用
    var locationNames: [String] = []

    // MARK: - Delete State
    var isEditMode: Bool = false
    var showDeleteConfirmation: Bool = false
    var itemToDelete: String? = nil
    var isDeletingItem: Bool = false

    private let closetClient: ClosetClientProtocol
    private let deleteClosetItemClient: DeleteClosetItemClientProtocol
    private var loadTask: Task<Void, Never>?

    init(
        closetClient: ClosetClientProtocol = ClosetClient(),
        deleteClosetItemClient: DeleteClosetItemClientProtocol = DeleteClosetItemClient()
    ) {
        self.closetClient = closetClient
        self.deleteClosetItemClient = deleteClosetItemClient
        loadProfileFromDefaults()
        loadLocationNames()
    }

    // フィルタリング済みアイテム
    var filteredItems: [ClosetItem] {
        let itemsWithImage = closetItems.filter { item in
            guard let imageUrl = item.image_url, !imageUrl.isEmpty else {
                return false
            }
            return true
        }

        return itemsWithImage.filter { $0.clothingCategory == selectedCategory }
    }

    func loadItems() async {
        // 前のタスクをキャンセル
        loadTask?.cancel()

        // 新しいタスクを作成
        loadTask = Task {
            guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
                ToastManager.shared.show("ユーザー情報が取得できませんでした")
                return
            }

            isLoading = true

            defer {
                isLoading = false
            }

            do {
                let result = try await closetClient.get(uid: uid, itemType: nil)

                switch result {
                case .success(let response):
                    closetItems = response.items
                case .failure(let error):
                    ToastManager.shared.show(error.errorDescription ?? "エラーが発生しました")
                }
            } catch is CancellationError {
                return
            } catch {
                ToastManager.shared.show("通信エラーが発生しました: \(error.localizedDescription)")
            }
        }

        await loadTask?.value
    }

    /// 画像編集で差し替えたアイテムをローカル一覧へ反映する (位置を保ったまま置換)
    func replaceItem(oldId: String, with newItem: ClosetItem) {
        if let index = closetItems.firstIndex(where: { $0.id == oldId }) {
            closetItems[index] = newItem
        } else {
            closetItems.insert(newItem, at: 0)
        }
    }

    // MARK: - Delete Methods

    func toggleEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditMode.toggle()
        }
        if !isEditMode {
            itemToDelete = nil
            showDeleteConfirmation = false
        }
    }

    func requestDelete(itemId: String) {
        itemToDelete = itemId
        showDeleteConfirmation = true
    }

    func deleteItem() async {
        guard let itemId = itemToDelete,
              let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else { return }

        isDeletingItem = true
        defer { isDeletingItem = false }

        do {
            let result = try await deleteClosetItemClient.delete(uid: uid, itemId: itemId)
            switch result {
            case .success(let response):
                if response.success {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        closetItems.removeAll { $0.id == itemId }
                    }
                    itemToDelete = nil
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditMode = false
                    }
                } else {
                    ToastManager.shared.show(response.message)
                }
            case .failure(let error):
                ToastManager.shared.show(error.errorDescription ?? "削除に失敗しました")
            }
        } catch {
            ToastManager.shared.show("削除に失敗しました")
        }
    }

    // MARK: - Profile Management

    func reloadProfile() {
        loadProfileFromDefaults()
        loadLocationNames()
    }

    private func loadLocationNames() {
        var names: [String] = []
        let mainCode = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue)
        if let main = Prefecture.find(byCode: mainCode) {
            names.append(main.name)
        }
        let additionalCodes = UserDefaults.standard.stringArray(
            forKey: UserDefaultsKey.additionalPrefectureCodes.rawValue
        ) ?? []
        names.append(contentsOf: additionalCodes.compactMap { Prefecture.find(byCode: $0)?.name })
        locationNames = names
    }

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
            // エンコードエラー時は何もしない
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
            // 固定ファイル名を使用（毎回上書き）
            let filename = "profile_image.jpg"

            // 古いプロフィール画像を削除
            deleteOldProfileImage()

            if let url = saveImageToDocuments(data: data, filename: filename) {
                // ファイル名のみを保存（フルパスではなく）
                updateProfileImage(url: filename)
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
            return nil
        }
    }

    private func deleteOldProfileImage() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        // profile_で始まるファイルをすべて削除
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.lastPathComponent.hasPrefix("profile_") {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            // エラーは無視
        }
    }

    // プロフィール画像の実際のURLを取得するヘルパーメソッド
    func getProfileImageURL() -> URL? {
        guard let filename = profileInfo?.profileImageUrl else { return nil }

        // file://で始まる場合は古い形式（フルパス）なので、そのまま返す
        if filename.hasPrefix("file://") {
            return URL(string: filename)
        }

        // ファイル名のみの場合は、ドキュメントディレクトリのパスを構築
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        return documentsDirectory.appendingPathComponent(filename)
    }
}
