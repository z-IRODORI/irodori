//
//  SelectStandardItemViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/14.
//

import Foundation
import Observation

@MainActor
@Observable
final class SelectStandardItemViewModel {
    var items: [StandardItem] = []
    var isLoading = false
    var errorMessage: String?
    var isRegistering = false
    var registrationSuccess = false

    // フィルター
    var selectedGender: String? = nil
    var selectedMainCategory: String? = nil
    var selectedSubCategory: String? = nil
    var selectedColor: String? = nil

    // 選択管理
    var selectedItems: Set<String> = []

    // コーデ提案結果
    var coordinateRecommendResults: [CoordinateRecommendResult] = []
    var selectedItemsForRecommend: [StandardItem] = []  // 提案用に保持（最大3つ）

    private let client: StandardItemsClientProtocol
    private let bulkRegisterClient: BulkItemRegisterClientProtocol
    private let bulkCoordinateClient: BulkCoordinateRecommendClientProtocol

    init(
        client: StandardItemsClientProtocol = StandardItemsClient(),
        bulkRegisterClient: BulkItemRegisterClientProtocol = BulkItemRegisterClient(),
        bulkCoordinateClient: BulkCoordinateRecommendClientProtocol = BulkCoordinateRecommendClient()
    ) {
        self.client = client
        self.bulkRegisterClient = bulkRegisterClient
        self.bulkCoordinateClient = bulkCoordinateClient
        // UserDefaultsからgenderを取得
        self.selectedGender = UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue) ?? "men"
    }

    func fetchItems() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let result = try await client.get(
                gender: selectedGender,
                mainCategory: selectedMainCategory,
                subCategory: selectedSubCategory,
                color: selectedColor,
                limit: 300  // 標準アイテム拡充後は性別ごとに100件を超えるため
            )

            switch result {
            case .success(let response):
                // 全てのパラメータが揃っているアイテムのみをフィルタリング
                let filtered = response.items.filter { item in
                    !item.gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !item.main_category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !item.sub_category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !item.color.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                // sub_category + color の組み合わせが重複する場合、後に来るものを優先して1つだけ残す
                var seen: [String: String] = [:]
                for item in filtered {
                    seen["\(item.sub_category)_\(item.color)"] = item.id
                }
                items = filtered.filter { seen["\($0.sub_category)_\($0.color)"] == $0.id }
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.errorDescription
                items = []
            }
        } catch {
            errorMessage = "通信エラーが発生しました: \(error.localizedDescription)"
            items = []
        }
    }

    func applyFilters(
        gender: String? = nil,
        mainCategory: String? = nil,
        subCategory: String? = nil,
        color: String? = nil
    ) async {
        selectedGender = gender
        selectedMainCategory = mainCategory
        selectedSubCategory = subCategory
        selectedColor = color

        await fetchItems()
    }

    func clearFilters() async {
        selectedGender = nil
        selectedMainCategory = nil
        selectedSubCategory = nil
        selectedColor = nil

        await fetchItems()
    }

    // MARK: - Selection Management

    func toggleSelection(_ item: StandardItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func isSelected(_ item: StandardItem) -> Bool {
        return selectedItems.contains(item.id)
    }

    func clearSelection() {
        selectedItems.removeAll()
    }

    // MARK: - Bulk Registration

    func registerSelectedItems() async {
        guard !selectedItems.isEmpty else { return }

        isRegistering = true
        errorMessage = nil
        registrationSuccess = false
        defer { isRegistering = false }

        // Get user credentials from UserDefaults
        guard let userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
            errorMessage = "ユーザー認証情報が見つかりません"
            return
        }

        // user_tokenはuser_idと同じ値を使用
        let userToken = userId

        // Get selected items
        let itemsToRegister = items.filter { selectedItems.contains($0.id) }

        // Download images and prepare metadata
        var itemsData: [(metadata: BulkItemMetadata, imageData: Data)] = []

        for (index, item) in itemsToRegister.enumerated() {
            // Download image
            guard let imageUrl = URL(string: item.storage_url) else {
                errorMessage = "画像URLが不正です: \(item.storage_url)"
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: imageUrl)

                // Normalize and clean strings (Unicode NFC normalization + trim)
                func normalizeString(_ str: String) -> String {
                    return str
                        .precomposedStringWithCanonicalMapping  // Unicode NFC normalization
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }

                let normalizedGender = normalizeString(item.gender)
                let normalizedMainCategory = normalizeString(item.main_category)
                let normalizedSubCategory = normalizeString(item.sub_category)
                let normalizedColor = normalizeString(item.color)

                // item_type は main_category と sub_category を組み合わせて生成
                // バックエンドの要求に合わせて必須フィールドとして設定
                let itemType = "\(normalizedMainCategory)_\(normalizedSubCategory)"

                // Create metadata
                let metadata = BulkItemMetadata(
                    index: index,
                    gender: normalizedGender,
                    main_category: normalizedMainCategory,
                    sub_category: normalizedSubCategory,
                    color: normalizedColor,
                    item_type: itemType,  // 必須フィールド
                    category: normalizedSubCategory,  // category にも sub_category を設定
                    coordinate_id: nil
                )

                itemsData.append((metadata: metadata, imageData: data))
            } catch {
                errorMessage = "画像のダウンロードに失敗しました: \(error.localizedDescription)"
                return
            }
        }

        // Register items
        do {
            let result = try await bulkRegisterClient.register(
                userId: userId,
                userToken: userToken,
                items: itemsData
            )

            switch result {
            case .success(let response):
                if response.status == "success" && response.failed_count == 0 {
                    // 登録成功後、コーデ提案を取得
                    let registeredItems = itemsToRegister.prefix(3)  // 最大3アイテム
                    selectedItemsForRecommend = Array(registeredItems)

                    await fetchCoordinateRecommendations(for: Array(registeredItems))

                    registrationSuccess = true
                    clearSelection()
                } else {
                    let errorDetails = response.errors.map { "[\($0.index)]: \($0.error)" }.joined(separator: "\n")
                    errorMessage = "一部のアイテムの登録に失敗しました:\n\(errorDetails)"
                }
            case .failure(let error):
                errorMessage = "登録エラー: \(error.errorDescription)"
            }
        } catch {
            errorMessage = "通信エラー: \(error.localizedDescription)"
        }
    }

    private func fetchCoordinateRecommendations(for items: [StandardItem]) async {
        let requestItems = items.enumerated().map { index, item in
            BulkCoordinateRecommendItem(
                item_id: item.id,
                gender: item.gender,
                input_type: item.main_category,
                category: item.sub_category,
                text: item.color,
                num_outfits: 10,
                num_candidates: 5
            )
        }

        let request = BulkCoordinateRecommendRequest(items: requestItems)

        do {
            let result = try await bulkCoordinateClient.post(request: request)

            switch result {
            case .success(let response):
                coordinateRecommendResults = response.results.filter { $0.status == "success" }
            case .failure(let error):
                errorMessage = "コーデ提案の取得に失敗しました: \(error.errorDescription)"
            }
        } catch {
            errorMessage = "通信エラーが発生しました: \(error.localizedDescription)"
        }
    }
}
