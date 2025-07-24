//
//  CoordinateReviewViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/16.
//

import UIKit
import CoreML

@MainActor
@Observable
final class CoordinateReviewViewModel {
    let coordinateImage: UIImage
    let apiClient: FashionReviewClientProtocol
    let model: Model?
    init(coordinateImage: UIImage, apiClient: FashionReviewClientProtocol) {
        self.coordinateImage = coordinateImage
        self.apiClient = apiClient

        // Model の初期化
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        do {
            self.model = try Model(configuration: config)
        } catch {
            self.model = nil
            print("モデルのロードまたは設定に失敗しました: \(error)")
        }
    }

    var fashionReview: FashionReviewResponse?
    var isFinishedRequest = false

    // アイテム抽出の結果
    var outputUIImage: UIImage = .init(resource: .coordinate4)
    var topsUIImage: UIImage?
    var bottomsUIImage: UIImage?

    func loadingOnAppear() async {
        segment()
        do {
            let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue)!
            let fashionReviewResponse: Result<FashionReviewResponse, Error> = try await apiClient.post(
                uid: uid,
                image: coordinateImage.correctOrientation,
                purposeNum: nil//tag.number
            )

            switch fashionReviewResponse {
            case .success(let fashionReview):
                self.fashionReview = fashionReview
                isFinishedRequest = true
            case .failure(let error):
                print("Error: \(error)")
                return
            }
        } catch {
            // TODO: - エラー処理
        }
    }

    func segment() {
        Task {
            guard let pixelBuffer = coordinateImage.toCVPixelBuffer() else {
                throw NSError(domain: "ImageConversion", code: -1, userInfo: nil)
            }
            let input = ModelInput(image: pixelBuffer)
            guard let model else { return }
            let output = try await model.prediction(input: input)
            let items: [SegmentationConverter.FashionItemType] = output.classLabelsShapedArray.scalars.map { SegmentationConverter.fashionItems[Int($0)] }   // [.background, .background, ・・・]
            guard let outputUIImage = SegmentationConverter.createOutputUIImage(output: output) else { return }
            let topsMaskUIImage = SegmentationConverter.createMaskUIImage(from: items, targetItems: [.upperClothes, .leftArm, .rightArm, .bag]).resize(to: coordinateImage.size)
            let squareTopsUIImage = coordinateImage.mask(image: topsMaskUIImage).croppedNonTransparentToSquare512()!
            let bottomsMaskUIImage = SegmentationConverter.createMaskUIImage(from: items, targetItems: [.belt, .pants, .skirt]).resize(to: coordinateImage.size)
            let squareBottomsUIImage = coordinateImage.mask(image: bottomsMaskUIImage).croppedNonTransparentToSquare512()!

            self.outputUIImage = outputUIImage
            self.topsUIImage = squareTopsUIImage
            self.bottomsUIImage = squareBottomsUIImage
        }
    }
}
