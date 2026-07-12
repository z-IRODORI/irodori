//
//  CoordinateCollageViewModel.swift
//  irodori
//
//  コーデコラージュ生成画面の ViewModel。
//  入力(コーデ3枚以上 + 背景色) → ローディング → 結果 の 3 ステップを管理する
//  (OutfitSuggestionViewModel と同じステップ構成)。
//  - 生成に使う画像データはキャッシュし、「別パターンで作る」は
//    再ダウンロードなしで即再生成する (seed 無指定なので配置が毎回変わる)
//

import SwiftUI
import Photos

@Observable
@MainActor
final class CoordinateCollageViewModel {
    enum Step { case input, loading, result }

    private let collageClient: CoordinateCollageClientProtocol
    private let listClient: CoordinateListClientProtocol

    /// 登録済みコーデのサムネ (http URL)
    struct RegisteredCoordinate: Identifiable, Hashable {
        let id: String
        let url: String            // 撮影画像URL (選択グリッド表示用)
        let cutoutURL: String?     // 人物切り取り後URL (あればコラージュ送信に使い、サーバー切り抜きを省く)
    }

    // ステップ
    var step: Step = .input

    // 選択ソース
    var registeredCoordinates: [RegisteredCoordinate] = []
    var selectedCoordinateIDs: Set<String> = []
    var pickedImages: [UIImage] = []

    // 設定
    var backgroundColor: Color = Color(red: 1.0, green: 140.0 / 255.0, blue: 66.0 / 255.0)  // #FF8C42 オレンジ

    // 状態
    var isLoadingCoordinates = false
    var isShuffling = false
    var resultImage: UIImage?
    var errorMessage: String?

    /// 生成に使った合計枚数 (結果画面のキャプション用)
    private(set) var generatedImageCount = 0

    /// アップロード用に準備した画像データ。選択が変わるまで再利用し、
    /// 「別パターンで作る」での登録コーデ再ダウンロードを避ける
    private var preparedImageData: [Data] = []
    private var generationTask: Task<Void, Never>?

    /// 直近何ヶ月分の登録コーデを取得するか
    private let monthsToFetch = 6

    /// アップロード前に縮小する長辺 (px)。
    /// サーバーは長辺 576px に縮小してから人物を切り抜くため、これ以上の
    /// 解像度を送っても仕上がりは変わらず、通信時間だけが増える。
    private let uploadLongEdge: CGFloat = 1600

    init(
        collageClient: CoordinateCollageClientProtocol = CoordinateCollageClient(),
        listClient: CoordinateListClientProtocol = CoordinateListClient()
    ) {
        self.collageClient = collageClient
        self.listClient = listClient
    }

    // MARK: - Derived

    /// 選択合計枚数 (登録コーデ + 写真フォルダ)
    var totalSelectedCount: Int {
        selectedCoordinateIDs.count + pickedImages.count
    }

    /// 生成に必要な残り枚数
    var remainingCount: Int {
        max(0, 3 - totalSelectedCount)
    }

    /// 生成可能か (3枚以上選択)
    var canGenerate: Bool {
        totalSelectedCount >= 3
    }

    // MARK: - Load registered coordinates

    func loadRegisteredCoordinates() async {
        guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue), !uid.isEmpty else {
            return
        }

        isLoadingCoordinates = true
        defer { isLoadingCoordinates = false }

        let calendar = Calendar.current
        let now = Date()
        var seen = Set<String>()
        var coordinates: [RegisteredCoordinate] = []

        for offset in 0..<monthsToFetch {
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)

            guard let result = try? await listClient.get(uid: uid, year: year, month: month),
                  case .success(let list) = result else {
                continue
            }

            for item in list {
                guard let path = item.coodinate_image_path,
                      !path.isEmpty,
                      path.hasPrefix("http") else { continue }
                let id = item.id ?? path
                if seen.contains(id) { continue }
                seen.insert(id)
                let cutout = (item.cutout_image_path?.isEmpty == false) ? item.cutout_image_path : nil
                coordinates.append(RegisteredCoordinate(id: id, url: path, cutoutURL: cutout))
            }
        }

        registeredCoordinates = coordinates
    }

    // MARK: - Selection

    func toggleCoordinate(_ id: String) {
        if selectedCoordinateIDs.contains(id) {
            selectedCoordinateIDs.remove(id)
        } else {
            selectedCoordinateIDs.insert(id)
        }
        preparedImageData = []  // 選択が変わったので準備済みデータを無効化
    }

    func addPickedImages(_ images: [UIImage]) {
        pickedImages.append(contentsOf: images)
        preparedImageData = []
    }

    func removePickedImage(at index: Int) {
        guard pickedImages.indices.contains(index) else { return }
        pickedImages.remove(at: index)
        preparedImageData = []
    }

    // MARK: - Generate

    func generate() {
        guard canGenerate, step != .loading else { return }
        errorMessage = nil
        step = .loading
        generationTask = Task { await runGenerate() }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        step = .input
    }

    func backToInput() {
        step = .input
        errorMessage = nil
    }

    private func runGenerate() async {
        do {
            let images = try await prepareImageDataIfNeeded()
            guard images.count >= 3 else {
                failBackToInput("画像の準備に失敗しました。もう一度お試しください")
                return
            }
            try Task.checkCancellation()

            let result = try await requestCollage(images: images)
            try Task.checkCancellation()

            switch result {
            case .success(let response):
                if let image = await downloadResultImage(response) {
                    try Task.checkCancellation()
                    resultImage = image
                    generatedImageCount = response.image_count
                    step = .result
                    Haptic.notify(.success)
                } else {
                    failBackToInput("合成画像の取得に失敗しました。もう一度お試しください")
                }
            case .failure:
                failBackToInput("コラージュの生成に失敗しました。少し時間をおいて試してください")
            }
        } catch is CancellationError {
            // キャンセル時は cancelGeneration() が既に .input へ戻している
        } catch {
            failBackToInput("コラージュの生成に失敗しました。少し時間をおいて試してください")
        }
    }

    /// 別パターンで作る: 準備済み画像を再利用して即再生成 (再ダウンロードなし)
    func shuffle() async {
        guard !preparedImageData.isEmpty, !isShuffling else { return }
        isShuffling = true
        defer { isShuffling = false }

        do {
            let result = try await requestCollage(images: preparedImageData)
            if case .success(let response) = result,
               let image = await downloadResultImage(response) {
                resultImage = image
                Haptic.notify(.success)
                return
            }
        } catch {}

        // 失敗しても直前のコラージュは有効なので結果画面に留まる
        Haptic.notify(.error)
        ToastManager.shared.show("別パターンの作成に失敗しました")
    }

    private func requestCollage(images: [Data]) async throws -> Result<CoordinateCollageResponse, HTTPError> {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        return try await collageClient.generate(
            userId: uid,
            images: images,
            backgroundColorHex: backgroundColor.toHexString(),
            seed: nil
        )
    }

    private func failBackToInput(_ message: String) {
        guard !Task.isCancelled else { return }
        errorMessage = message
        step = .input
        Haptic.notify(.error)
    }

    private func prepareImageDataIfNeeded() async throws -> [Data] {
        if !preparedImageData.isEmpty { return preparedImageData }

        var imageDataList: [Data] = []

        // 1. 選択した登録コーデをダウンロード。
        //    切り取り済み画像があれば透過保持で PNG 送信し、サーバー側の人物切り抜きを省く。
        let selectedCoords = registeredCoordinates
            .filter { selectedCoordinateIDs.contains($0.id) }
        for coord in selectedCoords {
            try Task.checkCancellation()
            let useCutout = (coord.cutoutURL?.isEmpty == false)
            let urlString = useCutout ? (coord.cutoutURL ?? coord.url) : coord.url
            guard let url = URL(string: urlString),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else {
                continue
            }
            let prepared = image.fixedOrientation().resizedToFit(longEdge: uploadLongEdge)
            // 切り取り画像は透過を保つため PNG、撮影画像は従来通り JPEG
            let encoded = useCutout ? prepared.pngData() : prepared.jpegData(compressionQuality: 0.8)
            if let encoded {
                imageDataList.append(encoded)
            }
        }

        // 2. 写真フォルダから選んだ画像
        for image in pickedImages {
            if let jpeg = image.fixedOrientation()
                .resizedToFit(longEdge: uploadLongEdge)
                .jpegData(compressionQuality: 0.8) {
                imageDataList.append(jpeg)
            }
        }

        preparedImageData = imageDataList
        return imageDataList
    }

    private func downloadResultImage(_ response: CoordinateCollageResponse) async -> UIImage? {
        // 本番: collage_url をダウンロード
        if !response.collage_url.isEmpty,
           let url = URL(string: response.collage_url),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let image = UIImage(data: data) {
            return image
        }
        // フォールバック: base64
        if !response.collage_base64.isEmpty,
           let data = Data(base64Encoded: response.collage_base64),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    // MARK: - Save to Photos

    func saveResultToPhotos() {
        guard let image = resultImage else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    Haptic.notify(.error)
                    ToastManager.shared.show("写真へのアクセスが許可されていません。設定から許可してください")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                Task { @MainActor in
                    if success {
                        Haptic.notify(.success)
                        ToastManager.shared.show("写真に保存しました", style: .normal)
                    } else {
                        Haptic.notify(.error)
                        ToastManager.shared.show("保存に失敗しました。もう一度お試しください")
                    }
                }
            }
        }
    }
}

// MARK: - Color → Hex

extension Color {
    /// SwiftUI Color を "#RRGGBB" 文字列に変換する
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let r = Int(round(max(0, min(1, red)) * 255))
        let g = Int(round(max(0, min(1, green)) * 255))
        let b = Int(round(max(0, min(1, blue)) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
