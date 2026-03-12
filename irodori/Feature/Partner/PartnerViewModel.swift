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
    var errorMessage: String?
    var showError: Bool = false

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
                } else {
                    // status: "no_data"の場合
                    errorMessage = response.insight
                    showError = true
                }
            case .failure(let error):
                errorMessage = error.errorDescription
                showError = true
            }
        } catch {
            errorMessage = "インサイトの取得に失敗しました"
            showError = true
        }
    }
}
