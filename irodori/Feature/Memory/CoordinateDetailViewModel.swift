//
//  CoordinateDetailViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import UIKit

@Observable
@MainActor
final class CoordinateDetailViewModel {
    let coordinateId: String
    let coordinateImageURL: String
    let coordinateDetailClient: CoordinateDetailClientProtocol
    let updateDisplayTypeClient: UpdateCoordinateDisplayTypeClientProtocol

    var coordinateDetail: CoordinateDetailResponse? = nil
    var isLoadingDetail = false
    var willShowRecommendCoordinateView = false
    var willShowChatView = false
    // 大画像に表示するURL (display_type 切替で更新)
    var displayedImageURL: String
    var isUpdatingDisplayType = false
    /// 着用アイテムを直している最中 (差し替え・外す)
    var isEditingItem = false
    var isDeleting = false

    init(
        coordinateId: String,
        coordinateImageURL: String,
        coordinateDetailClient: CoordinateDetailClientProtocol,
        updateDisplayTypeClient: UpdateCoordinateDisplayTypeClientProtocol = UpdateCoordinateDisplayTypeClient()
    ) {
        self.coordinateId = coordinateId
        self.coordinateImageURL = coordinateImageURL
        self.coordinateDetailClient = coordinateDetailClient
        self.updateDisplayTypeClient = updateDisplayTypeClient
        self.displayedImageURL = coordinateImageURL
    }

    /// 切り取り画像を持っているか (表示切替トグルの表示条件)
    var hasCutout: Bool {
        if let cutout = coordinateDetail?.current_coordinate.cutout_image_path, !cutout.isEmpty {
            return true
        }
        return false
    }

    /// 現在の一覧表示種別
    var currentDisplayType: CoordinateDisplayType {
        CoordinateDisplayType(rawValue: coordinateDetail?.current_coordinate.display_type ?? "") ?? .captured
    }

    func onAppear() async {
        await fetchCoordinateDetail()
    }

    func fetchCoordinateDetail() async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        do {
            let result = try await coordinateDetailClient.get(coordinateId: coordinateId)
            switch result {
            case .success(let response):
                coordinateDetail = response
                displayedImageURL = response.current_coordinate.displayImageURL
            case .failure(let error):
                print("Failed to fetch coordinate detail: \(error)")
            }
        } catch {
            print("Error fetching coordinate detail: \(error)")
        }
    }

    /// 一覧表示に使う画像種別 (撮影/切り取り) を切り替えて永続化する。
    func setDisplayType(_ type: CoordinateDisplayType) async {
        guard let detail = coordinateDetail, type != currentDisplayType, !isUpdatingDisplayType else { return }
        isUpdatingDisplayType = true
        defer { isUpdatingDisplayType = false }

        guard let result = try? await updateDisplayTypeClient.update(coordinateId: coordinateId, displayType: type.rawValue),
              case .success = result else {
            ToastManager.shared.show("表示の切り替えに失敗しました")
            return
        }

        // ローカルの詳細を更新して即時反映する
        let cc = detail.current_coordinate
        let updatedCoordinate = CoordinateDetailResponse.CurrentCoordinate(
            id: cc.id,
            date: cc.date,
            coodinate_image_path: cc.coodinate_image_path,
            cutout_image_path: cc.cutout_image_path,
            display_type: type.rawValue
        )
        coordinateDetail = CoordinateDetailResponse(
            current_coordinate: updatedCoordinate,
            items: detail.items,
            ai_catchphrase: detail.ai_catchphrase,
            ai_review_comment: detail.ai_review_comment
        )
        displayedImageURL = updatedCoordinate.displayImageURL
        Haptic.notify(.success)
    }

    private var uid: String { UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? "" }

    /// 着用アイテムをクローゼットの服に差し替える (検出が違っていたとき)
    func replaceItem(_ itemId: String, with closetItemId: String) async -> Bool {
        await editItem { try await CoordinateItemEditClient().replace(uid: self.uid, coordinateId: self.coordinateId, itemId: itemId, closetItemId: closetItemId) }
    }

    /// 着用アイテムをコーデから外す (クローゼットの服は残す)
    func removeItem(_ itemId: String) async -> Bool {
        await editItem { try await CoordinateItemEditClient().remove(uid: self.uid, coordinateId: self.coordinateId, itemId: itemId) }
    }

    private func editItem(_ call: () async throws -> Result<CoordinateDetailResponse, HTTPError>) async -> Bool {
        isEditingItem = true
        defer { isEditingItem = false }
        guard let result = try? await call(), case .success(let response) = result else {
            ToastManager.shared.show("アイテムを直せませんでした")
            return false
        }
        coordinateDetail = response
        Haptic.notify(.success)
        NotificationCenter.default.post(name: .coordinateDidChange, object: coordinateId)
        return true
    }

    /// コーデを削除する (Firestore と Storage から)。成功したら true
    func deleteCoordinate() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }
        guard let result = try? await DeleteCoordinateClient().delete(uid: uid, coordinateId: coordinateId),
              case .success(let res) = result, res.success else {
            ToastManager.shared.show("削除できませんでした")
            return false
        }
        NotificationCenter.default.post(name: .coordinateDidChange, object: coordinateId)
        return true
    }

    func tappedRecommendCoordinateButton() {
        willShowRecommendCoordinateView.toggle()
    }

    func tappedWillShowChatView() {
        willShowChatView.toggle()
    }
}
