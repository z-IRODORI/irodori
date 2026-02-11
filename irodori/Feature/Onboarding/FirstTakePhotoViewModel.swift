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
    var errorMessage: String?
    
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
            errorMessage = "ユーザー情報が取得できませんでした"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await fashionReviewClient.post(uid: uid, image: image, topsImage: nil, bottomsImage: nil, purposeNum: nil)

            switch result {
            case .success(let response):
                print("Success: \(response)")
                // TODO: 成功時の処理（次の画面への遷移など）
                showConfirmationView = false
                selectedImage = nil
            case .failure(let error):
                print("Error: \(error)")
                errorMessage = "画像の送信に失敗しました"
            }
        } catch {
            print("Unexpected error: \(error)")
            errorMessage = "予期しないエラーが発生しました"
        }
        
        isLoading = false
    }

    func setupFirstTakePhotoIfNeeded() {
        // 初回撮影済みの場合何もせずreturn
        if userDefaults.bool(forKey: UserDefaultsKey.finishedFirstTakePhoto.rawValue) {
            return
        }
        // 初回撮影の時はfinishedFirstTakePhotoにtrueを設定する
        userDefaults.set(true, forKey: UserDefaultsKey.finishedFirstTakePhoto.rawValue)
    }
}
