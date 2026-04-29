//
//  PartnerViewModel.swift
//  irodori
//
//  Created by Claude on 2026/03/12.
//

import Foundation

@MainActor
@Observable
final class PartnerViewModel {
    var userInsight: UserInsightResponse?
    var isLoading: Bool = false

    private let apiClient: UserInsightClientProtocol

    init(apiClient: UserInsightClientProtocol = UserInsightClient()) {
        self.apiClient = apiClient
    }

    func fetchUserInsight() async {
        isLoading = true
        defer { isLoading = false }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""

        do {
            let result = try await apiClient.get(uid: uid)

            switch result {
            case .success(let response):
                if response.status == "success" {
                    self.userInsight = response

                    // FashionTypeの画像情報をUserDefaultsに保存
                    if let fashionType = response.fashion_type {
                        let partnerImage = fashionType.type_name
                        let partnerIconImage = "\(fashionType.type_name)_icon"

                        UserDefaults.standard.set(partnerImage, forKey: UserDefaultsKey.partnerImage.rawValue)
                        UserDefaults.standard.set(partnerIconImage, forKey: UserDefaultsKey.partnerIconImage.rawValue)
                    }
                } else {
                    ToastManager.shared.show(response.insight ?? "相棒情報がありません")
                }
            case .failure(let error):
                ToastManager.shared.show(error.errorDescription ?? "エラーが発生しました")
            }
        } catch {
            ToastManager.shared.show("相棒コメントの取得に失敗しました")
        }
    }
}
