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
    var selectedRecommendCoordinate: RecommendCoordinate = .init(id: 0, image_url: "", pin_url_guess: "")
    var isTappedRecommendCoordinate = false

    let coordinateImage: UIImage
    let apiClient: FashionReviewClientProtocol
    let recommendCoordinateClient: RecommendCoordinateClientProtocol
    let analysisCoordinateClient: AnalysisCoordinateClientProtocol
    let model: Model?
    
    init(coordinateImage: UIImage, apiClient: FashionReviewClientProtocol, recommendCoordinateClient: RecommendCoordinateClientProtocol = RecommendCoordinateClient(), analysisCoordinateClient: AnalysisCoordinateClientProtocol = AnalysisCoordinateClient()) {
        self.coordinateImage = coordinateImage
        self.apiClient = apiClient
        self.recommendCoordinateClient = recommendCoordinateClient
        self.analysisCoordinateClient = analysisCoordinateClient

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
    var errroMessage: ErrorMessage?
    
    // おすすめコーディネート
    var recommendCoordinates: RecommendCoordinateResponse?

    // アイテム抽出の結果
    var outputUIImage: UIImage = .init(resource: .coordinate4)
    var topsUIImage: UIImage?
    var bottomsUIImage: UIImage?
    
    // コーディネート解析結果
    var analysisCoordinateResponse: AnalysisCoordinateResponse?
    var isLoadingAnalysisCoordinate = false

    func loadingOnAppear() async {
        await segment()
        await coordinateReview()
        
        // おすすめコーディネートとコーディネート解析は別タスクで実行（UI表示をブロックしない）
        Task { @MainActor in
            await fetchRecommendCoordinates()
            guard let recommendCoordinates = recommendCoordinates else { return }
            if !recommendCoordinates.coordinates.isEmpty {
                // recommendCoordinates の先頭のコーデを analysisCoordinateへ送る
                await analysisCoordinate(id: recommendCoordinates.coordinates[0].id)
            }
        }
    }

    func selectedRecommendCoordinate(recommendCoordinate: RecommendCoordinate) {
        Task { @MainActor in
            selectedRecommendCoordinate = recommendCoordinate
            await analysisCoordinate(id: recommendCoordinate.id)
        }
    }
    func updateSIstTapedRecomendCoordinate(isTaped: Bool) {
        isTappedRecommendCoordinate = isTaped
    }

    private func coordinateReview() async {
        do {
            let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue)!
            let fashionReviewResponse: Result<FashionReviewResponse, HTTPError> = try await apiClient.post(
                uid: uid,
                image: coordinateImage.correctOrientation,
                purposeNum: nil//tag.number
            )

            switch fashionReviewResponse {
            case .success(let fashionReview):
                self.fashionReview = fashionReview
                isFinishedRequest = true
            case .failure(let error):
                handleAPIError(error)
                return
            }
        } catch {
            handleAPIError(error)
        }
    }

    func segment() async {
        guard let pixelBuffer = coordinateImage.toCVPixelBuffer() else { return }
        let input = ModelInput(image: pixelBuffer)
        guard let model else { return }
        do {
            let output = try await model.prediction(input: input)
            let items: [SegmentationConverter.FashionItemType] = output.classLabelsShapedArray.scalars.map { SegmentationConverter.fashionItems[Int($0)] }   // [.background, .background, ・・・]
            guard let outputUIImage = SegmentationConverter.createOutputUIImage(output: output) else { return }
            let topsMaskUIImage = SegmentationConverter.createMaskUIImage(from: items, targetItems: [.upperClothes, .leftArm, .rightArm, .bag]).resize(to: coordinateImage.size)
            let bottomsMaskUIImage = SegmentationConverter.createMaskUIImage(from: items, targetItems: [.belt, .pants, .skirt]).resize(to: coordinateImage.size)
            // トップスとボトムス両方検出できたなら画像更新
            let squareTopsUIImage = coordinateImage.mask(image: topsMaskUIImage).croppedNonTransparentToSquare512()
            let squareBottomsUIImage = coordinateImage.mask(image: bottomsMaskUIImage).croppedNonTransparentToSquare512()

            if squareTopsUIImage == nil && squareBottomsUIImage == nil {
                setErrerMessage(mlError: .notTopsAndBottoms)
                return
            } else if squareTopsUIImage == nil {
                setErrerMessage(mlError: .notTops)
                return
            } else if squareBottomsUIImage == nil {
                setErrerMessage(mlError: .notBottoms)
                return
            }
             self.outputUIImage = outputUIImage
             self.topsUIImage = squareTopsUIImage!   // nil にはならない
             self.bottomsUIImage = squareBottomsUIImage!   // nil にはならない
        } catch {
            setErrerMessage(mlError: .unknwon)
        }
    }

    private func setErrerMessage(mlError: MLError) {
        errroMessage = .init(title: mlError.title, description: mlError.errorDescription)
    }

    
    private func fetchRecommendCoordinates() async {
        do {
            // 性別を取得（デフォルトは"other"）
            let gender = UserDefaults.standard.string(forKey: "gender") ?? "other"
            
            let result = try await recommendCoordinateClient.post(gender: gender)
            
            switch result {
            case .success(let response):
                recommendCoordinates = response
            case .failure(_):
                recommendCoordinates = nil
            }
        } catch {
            recommendCoordinates = nil
        }
    }
    
    private func analysisCoordinate(id: Int) async {
        isLoadingAnalysisCoordinate = true
        do {
            let gender = UserDefaults.standard.string(forKey: "gender") ?? "other"
            let response = try await analysisCoordinateClient.analysisCoordinate(
                id: id,
                gender: gender
            )
            analysisCoordinateResponse = response
        } catch {
            print("Analysis coordinate API error: \(error)")
        }
        isLoadingAnalysisCoordinate = false
    }

    private func handleAPIError(_ error: Error) {
        if let httpError = error as? HTTPError {
            errroMessage = .init(title: httpError.title, description: httpError.errorDescription)
        } else {
            errroMessage = .init(title: "通信エラー", description: "サーバーとの通信中にエラーが発生しました")
        }
    }
}
