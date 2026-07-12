//
//  SelectFirstTimePicViewModel.swift
//  irodori
//
//  Created by Assistant on 2025/12/07.
//

import SwiftUI
import Observation
import Combine

@MainActor
@Observable
final class FirstTakePhotoViewModel {
    private let userDefaults = UserDefaults.standard

    var showCameraView = false
    var showPhotoPicker = false
    var selectedImage: UIImage?
    var showConfirmationView = false
    var isLoading = false
    var capturedImageFromCamera: UIImage?

    private let fashionReviewClient: FashionReviewClientProtocol
    init(fashionReviewClient: FashionReviewClientProtocol) {
        self.fashionReviewClient = fashionReviewClient
    }

    func handleImageSelection(_ image: UIImage) {
        selectedImage = image
        showConfirmationView = true
    }

    func discardImage() {
        selectedImage = nil
        showConfirmationView = false
    }

    func sendImageToAPI() async {
        guard let image = selectedImage,
              let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
            ToastManager.shared.show("ユーザー情報が取得できませんでした")
            return
        }

        isLoading = true

        // 送信前に人物切り取りをオンデバイスで生成 (失敗しても nil のまま撮影画像だけで続行)
        let cutoutImage = try? await ItemNoiseRemover.removeBackgroundNoise(
            from: image.correctOrientation.resizedToFit(longEdge: 1440)
        )

        do {
            let result = try await fashionReviewClient.post(uid: uid, image: image, topsImage: nil, bottomsImage: nil, cutoutImage: cutoutImage, purposeNum: nil)

            switch result {
            case .success(let response):
                print("Success: \(response)")
                showConfirmationView = false
                selectedImage = nil
            case .failure(let error):
                print("Error: \(error)")
                ToastManager.shared.show("画像の送信に失敗しました")
            }
        } catch {
            print("Unexpected error: \(error)")
            ToastManager.shared.show("予期しないエラーが発生しました")
        }

        isLoading = false
    }
}
