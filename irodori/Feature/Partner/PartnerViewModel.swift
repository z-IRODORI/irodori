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

                    // サーバの相棒のタイプ (partner_state が正) を端末に写す
                    PartnerLocalMirror.apply(typeName: response.fashion_type?.type_name)
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
