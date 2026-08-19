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
    var fashionReview: FashionReviewResponse?
    var isFinishedRequest = false
    var currentDateString = ""
    var willShowRecommendCoordinateView = false
    let model: Model?
    // アイテム抽出の結果
    var outputUIImage: UIImage = .init(resource: .coordinate4)
    var topsUIImage: UIImage?
    var bottomsUIImage: UIImage?
    // 送信前にオンデバイス(Vision)で生成する人物切り取り(背景透過)画像。
    // これまでのコーデとして撮影画像と共に保存する。
    var cutoutImage: UIImage?
    // 検出位置 (正規化座標)。ローディング画面の検出ボックス表示用
    var topsBoundingRect: CGRect?
    var bottomsBoundingRect: CGRect?
    var errroMessage: ErrorMessage?
    /// v2: アイテム画像のバックグラウンド生成中フラグ (アイテム一覧に生成中表示を出す)
    var isGeneratingItems = false
    private var itemImagePollTask: Task<Void, Never>?
    private let coordinateDetailClient: CoordinateDetailClientProtocol = CoordinateDetailClient()

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
    func onAppear() async {
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
        //
        // v2 エンジンはサーバー側で全アイテムを検出するため、オンデバイス検出の
        // 失敗 (トップス/ボトムス未検出) では中断しない (成功すればローディング演出に使う)。
        await segment(failureAborts: AnalysisEngine.current == .legacy)

        if errroMessage == nil {
            // 送信前に人物切り取りをオンデバイスで実行 (サーバー側では切り取らない)
            await generatePersonCutout()
            await coordinateReview()
        }
    }

    /// 撮影画像から人物を背景透過で切り抜く (Vision 被写体マスク)。
    /// 失敗しても cutoutImage は nil のままで、撮影画像のみで続行する。
    private func generatePersonCutout() async {
        let source = coordinateImage.correctOrientation.resizedToFit(longEdge: 1440)
        // サーバーの切り抜き(segment_person_rgba, margin_ratio=0.045/人物短辺)と揃えて余白を持たせる
        cutoutImage = try? await ItemNoiseRemover.removeBackgroundNoise(from: source, marginRatio: 0.025)
    }

    func tappedRecommendCoordinateButton() {
        willShowRecommendCoordinateView.toggle()
    }

    private func coordinateReview() async {
        do {
            let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
            let startTime = CFAbsoluteTimeGetCurrent()
            // v2 はサーバー側でアイテム画像を生成するため tops/bottoms を送らない
            let isLegacy = AnalysisEngine.current == .legacy
            let fashionReviewResponse: Result<FashionReviewResponse, HTTPError> = try await apiClient.post(
                uid: uid,
                image: coordinateImage.correctOrientation,
                topsImage: isLegacy ? topsUIImage : nil,
                bottomsImage: isLegacy ? bottomsUIImage : nil,
                cutoutImage: cutoutImage,
                purposeNum: nil//tag.number
            )
            let endTime = CFAbsoluteTimeGetCurrent()
            let elapsedTime = endTime - startTime
            print("API処理時間: \(elapsedTime)秒")

            switch fashionReviewResponse {
            case .success(let fashionReview):
                self.fashionReview = fashionReview
                print(fashionReview)
                isFinishedRequest = true
                // v2: アイテム画像はバックグラウンド生成 → ポーリングで差し替える
                if fashionReview.items_generating == true {
                    startItemImagePolling(coordinateId: fashionReview.current_coordinate.id)
                }
            case .failure(let error):
                handleAPIError(error)
                return
            }
        } catch {
            handleAPIError(error)
        }
    }

    /// - Parameter failureAborts: トップス/ボトムス未検出をエラーとして中断するか。
    ///   legacy は true (従来どおり)。v2 はサーバー側で検出するため false。
    func segment(failureAborts: Bool = true) async {
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

            if squareTopsUIImage == nil || squareBottomsUIImage == nil {
                if failureAborts {
                    if squareTopsUIImage == nil && squareBottomsUIImage == nil {
                        setErrerMessage(mlError: .notTopsAndBottoms)
                    } else if squareTopsUIImage == nil {
                        setErrerMessage(mlError: .notTops)
                    } else {
                        setErrerMessage(mlError: .notBottoms)
                    }
                }
                return
            }
             self.outputUIImage = outputUIImage
             // 検出ボックスは目に見える服の位置を表すため、マスク (腕・バッグ込み) より狭い対象で計算する
             self.topsBoundingRect = SegmentationConverter.normalizedBoundingRect(of: [.upperClothes], in: items)
             self.bottomsBoundingRect = SegmentationConverter.normalizedBoundingRect(of: [.belt, .pants, .skirt], in: items)
             self.topsUIImage = squareTopsUIImage!   // nil にはならない
             self.bottomsUIImage = squareBottomsUIImage!   // nil にはならない
        } catch {
            setErrerMessage(mlError: .unknwon)
        }
    }

    // MARK: - v2: アイテム画像のポーリング差し替え

    /// バックグラウンド生成の完了を GET /api/coordinate/{id} で追いかけ、
    /// 完了したアイテムから item_image_path を差し替える (5秒間隔・最大約100秒)。
    private func startItemImagePolling(coordinateId: String) {
        isGeneratingItems = true
        itemImagePollTask?.cancel()
        itemImagePollTask = Task { [weak self] in
            defer { Task { @MainActor in self?.isGeneratingItems = false } }
            for _ in 0..<20 {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                guard let result = try? await self.coordinateDetailClient.get(coordinateId: coordinateId),
                      case .success(let detail) = result else { continue }
                self.applyUpdatedItemImages(detail.items)
                let stillPending = detail.items.contains { $0.image_source == "pending" }
                if !stillPending { return }
            }
        }
    }

    /// ポーリング結果のアイテム画像URLを表示中のレスポンスへ反映する
    private func applyUpdatedItemImages(_ updated: [CoordinateDetailResponse.CoordinateItem]) {
        guard var review = fashionReview else { return }
        var changed = false
        for u in updated {
            if let index = review.items.firstIndex(where: { $0.id == u.id }),
               !u.item_image_path.isEmpty,
               review.items[index].item_image_path != u.item_image_path {
                review.items[index].item_image_path = u.item_image_path
                changed = true
            }
        }
        if changed { fashionReview = review }
    }

    private func setCurrentDateString() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        dateFormatter.locale = Locale(identifier: "ja_JP")
        let now = Date()
        currentDateString = dateFormatter.string(from: now)
    }

    private func setErrerMessage(mlError: MLError) {
        errroMessage = .init(title: mlError.title, description: mlError.errorDescription)
    }
    
    private func handleAPIError(_ error: Error) {
        if let httpError = error as? HTTPError {
            errroMessage = .init(title: httpError.title, description: httpError.errorDescription)
        } else {
            errroMessage = .init(title: "通信エラー", description: "サーバーとの通信中にエラーが発生しました")
        }
    }

    func setupFirstTakePhotoIfNeeded() {
        // 初回撮影済みの場合何もせずreturn
        if UserDefaults.standard.bool(forKey: UserDefaultsKey.finishedFirstTakePhoto.rawValue) {
            return
        }
        // 初回撮影の時はfinishedFirstTakePhotoにtrueを設定する
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.finishedFirstTakePhoto.rawValue)
    }
}
