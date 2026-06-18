//
//  CoordinateCollageViewModel.swift
//  irodori
//
//  コーデコラージュ生成画面の ViewModel。
//  - 登録済みコーデを取得し、3枚以上選択 / 3枚未満なら写真フォルダから複数選択
//  - 背景色を選択
//  - API で人物切り抜き合成した「カッコいいコーデ画像」を生成・表示・保存
//

import SwiftUI
import Photos

@Observable
@MainActor
final class CoordinateCollageViewModel {
    private let collageClient: CoordinateCollageClientProtocol
    private let listClient: CoordinateListClientProtocol

    /// 登録済みコーデのサムネ (http URL)
    struct RegisteredCoordinate: Identifiable, Hashable {
        let id: String
        let url: String
    }

    // 選択ソース
    var registeredCoordinates: [RegisteredCoordinate] = []
    var selectedCoordinateIDs: Set<String> = []
    var pickedImages: [UIImage] = []

    // 設定
    var backgroundColor: Color = Color(red: 1.0, green: 140.0 / 255.0, blue: 66.0 / 255.0)  // #FF8C42 オレンジ

    // 状態
    var isLoadingCoordinates = false
    var isGenerating = false
    var resultImage: UIImage?
    var errorMessage: String?
    var didSaveToPhotos = false

    /// 直近何ヶ月分の登録コーデを取得するか
    private let monthsToFetch = 6

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

    /// 登録コーデが 3 枚以上あるか
    var hasEnoughRegisteredCoordinates: Bool {
        registeredCoordinates.count >= 3
    }

    /// 生成可能か (3枚以上選択 かつ 生成中でない)
    var canGenerate: Bool {
        totalSelectedCount >= 3 && !isGenerating
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
                coordinates.append(RegisteredCoordinate(id: id, url: path))
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
    }

    func addPickedImages(_ images: [UIImage]) {
        pickedImages.append(contentsOf: images)
    }

    func removePickedImage(at index: Int) {
        guard pickedImages.indices.contains(index) else { return }
        pickedImages.remove(at: index)
    }

    // MARK: - Generate

    func generate() async {
        guard canGenerate else { return }

        isGenerating = true
        resultImage = nil
        didSaveToPhotos = false
        errorMessage = nil
        defer { isGenerating = false }

        var imageDataList: [Data] = []

        // 1. 選択した登録コーデを URL からダウンロード
        let selectedURLs = registeredCoordinates
            .filter { selectedCoordinateIDs.contains($0.id) }
            .map { $0.url }
        for urlString in selectedURLs {
            guard let url = URL(string: urlString),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  let jpeg = image.fixedOrientation().jpegData(compressionQuality: 0.8) else {
                continue
            }
            imageDataList.append(jpeg)
        }

        // 2. 写真フォルダから選んだ画像
        for image in pickedImages {
            if let jpeg = image.fixedOrientation().jpegData(compressionQuality: 0.8) {
                imageDataList.append(jpeg)
            }
        }

        guard imageDataList.count >= 3 else {
            errorMessage = "画像の準備に失敗しました。もう一度お試しください"
            return
        }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let hex = backgroundColor.toHexString()

        do {
            let result = try await collageClient.generate(
                userId: uid,
                images: imageDataList,
                backgroundColorHex: hex,
                seed: nil
            )
            switch result {
            case .success(let response):
                await applyResult(response)
            case .failure(let error):
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyResult(_ response: CoordinateCollageResponse) async {
        // 本番: collage_url をダウンロード
        if !response.collage_url.isEmpty,
           let url = URL(string: response.collage_url),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let image = UIImage(data: data) {
            resultImage = image
            return
        }
        // フォールバック: base64
        if !response.collage_base64.isEmpty,
           let data = Data(base64Encoded: response.collage_base64),
           let image = UIImage(data: data) {
            resultImage = image
            return
        }
        errorMessage = "合成画像の取得に失敗しました"
    }

    // MARK: - Save to Photos

    func saveResultToPhotos() {
        guard let image = resultImage else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    self?.errorMessage = "写真へのアクセスが許可されていません。設定から許可してください"
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        self?.didSaveToPhotos = true
                    } else {
                        self?.errorMessage = "保存に失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
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
