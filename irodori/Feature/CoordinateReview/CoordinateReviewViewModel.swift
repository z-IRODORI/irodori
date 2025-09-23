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
    var selectedRecommendCoordinate: RecommendCoordinate = .init(
        id: 0, 
        image_url: "", 
        pin_url_guess: "", 
        coordinate_review: nil, 
        tops_categorize: nil, 
        bottoms_categorize: nil, 
        affiliate_tops: [], 
        affiliate_bottoms: []
    )
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
    var recommendCoordinatesState: FetchState<RecommendCoordinateResponse> = .initial

    // アイテム抽出の結果
    var outputUIImage: UIImage = .init(resource: .coordinate4)
    var topsUIImage: UIImage?
    var bottomsUIImage: UIImage?
    
    // コーディネート解析結果
    var analysisCoordinateState: FetchState<AnalysisCoordinateResponse> = .initial

    func loadingOnAppear() async {
        // CoreMLの制限により、segment()は単独で実行する必要がある
        // 理由:
        // 1. CoreMLは内部的にシリアル実行を強制する
        //    - Appleは並列予測を許可しているように見えるが、実際には内部で順次実行される
        //    - 複数のモデル予測を同時に実行しようとするとエラーが発生する可能性がある
        // 2. 計算ユニット（.cpuAndGPU）の競合
        //    - 複数の処理が同時にGPUリソースにアクセスしようとすると、推論コンテキストの作成に失敗
        //    - "Could not create inference context" エラーの原因
        // 3. メモリとリソースの競合
        //    - Neural EngineやGPUのメモリ制限により、並列実行時にリソース不足が発生
        await segment()
        
        // segmentが成功した場合のみ、API呼び出しを並列実行
        if errroMessage == nil {
            // coordinateReviewとfetchRecommendCoordinatesはAPI呼び出しのため並列実行可能
            async let reviewTask: Void = coordinateReview()
            async let recommendTask: Void = fetchRecommendCoordinates()
            
            _ = await (reviewTask, recommendTask)
            
            // おすすめコーディネートの解析
            if case .loaded(let response) = recommendCoordinatesState,
               !response.coordinates.isEmpty {
                await analysisCoordinate(id: response.coordinates[0].id)
            }
        }
    }

    func selectedRecommendCoordinate(recommendCoordinate: RecommendCoordinate) async {
        selectedRecommendCoordinate = recommendCoordinate

        // アフィリエイトデータがない場合はanalysisCoordinate APIを呼び出し
        let hasAffiliateData = !recommendCoordinate.affiliate_tops.isEmpty || !recommendCoordinate.affiliate_bottoms.isEmpty
        if !hasAffiliateData {
            await analysisCoordinate(id: recommendCoordinate.id)
        }
    }

    func updateSIstTapedRecomendCoordinate(isTaped: Bool) {
        isTappedRecommendCoordinate = isTaped
    }

    private func coordinateReview() async {
        do {
            let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
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
            let gender = UserDefaults.standard.string(forKey: "gender") ?? "men"

            recommendCoordinatesState = .loading
            let result = try await recommendCoordinateClient.post(gender: gender)
            
            switch result {
            case .success(let response):
                recommendCoordinatesState = .loaded(response)
            case .failure(let httpError):
                recommendCoordinatesState = .failed(httpError)
            }
        } catch {
            recommendCoordinatesState = .failed(HTTPError.badRequest)
        }
    }
    
    private func analysisCoordinate(id: Int) async {
        analysisCoordinateState = .loading
        do {
            let gender = UserDefaults.standard.string(forKey: "gender") ?? "other"
            let response = try await analysisCoordinateClient.analysisCoordinate(
                id: id,
                gender: gender
            )
            analysisCoordinateState = .loaded(response)
        } catch {
            print("Analysis coordinate API error: \(error)")
            analysisCoordinateState = .failed(HTTPError.badRequest)
        }
    }

    private func handleAPIError(_ error: Error) {
        if let httpError = error as? HTTPError {
            errroMessage = .init(title: httpError.title, description: httpError.errorDescription)
        } else {
            errroMessage = .init(title: "通信エラー", description: "サーバーとの通信中にエラーが発生しました")
        }
    }
}
