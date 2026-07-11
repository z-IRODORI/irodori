//
//  SearchedItemRegisterViewModel.swift
//  irodori
//
//  検索で選んだ画像を、端末内で背景除去し、属性を付けてユーザーの
//  クローゼットに登録する。登録は既存の POST /api/items/register/bulk
//  (BulkItemRegisterClient) をそのまま使い、バックエンドは変更しない。
//
//  メタデータ (種類/カテゴリ/カラー) はまずキーワードから推定し、色が
//  取れなければ切り抜き画像の平均色から推定する。いずれもユーザーが編集可能。
//

import UIKit
import Observation

@MainActor
@Observable
final class SearchedItemRegisterViewModel {
    let originalURL: URL     // 高画質(原寸)。まずこちらを取得する
    let thumbnailURL: URL    // 原寸が取得できないときのフォールバック

    var isLoading = true
    var loadFailed = false
    /// 背景除去に成功したか (失敗時は元画像のまま登録できる)
    var backgroundRemoved = false
    var workingImage: UIImage?
    var isRegistering = false

    // 属性 (種類 / カテゴリ / カラー) — 初期値は自動推定、ユーザー編集可
    var editedItemType: String
    var editedCategory: String
    var editedColor: String

    var canRegister: Bool { workingImage != nil && !isRegistering }

    private let registerClient: BulkItemRegisterClientProtocol
    private var preparedImage: UIImage?   // 切り抜き前(リサイズ済み)。retry時の再切り抜きに使う

    init(
        originalURL: URL,
        thumbnailURL: URL,
        keyword: String,
        registerClient: BulkItemRegisterClientProtocol = BulkItemRegisterClient()
    ) {
        self.originalURL = originalURL
        self.thumbnailURL = thumbnailURL
        self.registerClient = registerClient
        self.editedItemType = Self.inferItemType(from: keyword)
        self.editedCategory = Self.inferCategory(from: keyword)
        self.editedColor = Self.inferColor(from: keyword)  // 取れなければ "" → 画像から補完
    }

    // MARK: - 読み込み + 背景除去

    func load() async {
        guard workingImage == nil else { return }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        // まず原寸(高画質)を取得。取得できなければサムネにフォールバック。
        var downloaded = await Self.downloadImage(from: originalURL)
        if downloaded == nil {
            downloaded = await Self.downloadImage(from: thumbnailURL)
        }
        guard let image = downloaded else {
            loadFailed = true
            return
        }
        let prepared = image.fixedOrientation().resizedToFit(longEdge: 1024)
        preparedImage = prepared

        // 端末内 (Vision) で背景除去し、正方形化する (失敗しても正方形で続行)
        await applyCutout(to: prepared)

        // 色がキーワードから取れていなければ、切り抜き画像の平均色から推定
        if editedColor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let image = workingImage,
           let detected = Self.detectColorName(from: image) {
            editedColor = detected
        }
    }

    /// 画像を1件ダウンロードする (タイムアウト付き)。失敗時は nil。
    private static func downloadImage(from url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode < 400,
                  let image = UIImage(data: data) else { return nil }
            return image
        } catch {
            return nil
        }
    }

    /// 背景除去をやり直す (元画像から再抽出)。
    func retryRemoveBackground() async {
        guard let prepared = preparedImage else { return }
        await applyCutout(to: prepared)
        if backgroundRemoved {
            Haptic.impact(.soft)
        } else {
            ToastManager.shared.show("アイテムを検出できませんでした")
        }
    }

    /// 背景除去 → 正方形化して workingImage にセットする。
    /// クローゼットのアイテム画像は正方形が要件のため、normalizedToContentSquare() で
    /// 被写体を正方形キャンバス中央にフィットさせる (透過保持)。切り抜き失敗時も
    /// 元画像を正方形化 (透明パディング) して要件を満たす。
    private func applyCutout(to source: UIImage) async {
        if let cutout = try? await ItemNoiseRemover.removeBackgroundNoise(from: source),
           let squared = cutout.normalizedToContentSquare() {
            workingImage = squared
            backgroundRemoved = true
        } else {
            workingImage = source.normalizedToContentSquare() ?? source
            backgroundRemoved = false
        }
    }

    // MARK: - 登録

    /// クローゼットへ登録する。成功したら true。
    func register() async -> Bool {
        guard let image = workingImage, let data = image.pngData(),
              let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
            ToastManager.shared.show("登録に失敗しました")
            return false
        }
        isRegistering = true
        defer { isRegistering = false }

        let category = editedCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let color = editedColor.trimmingCharacters(in: .whitespacesAndNewlines)

        let metadata = BulkItemMetadata(
            index: 0,
            gender: UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue),
            main_category: nil,
            sub_category: nil,
            color: color.isEmpty ? nil : color,
            item_type: editedItemType,
            category: category.isEmpty ? nil : category,
            coordinate_id: nil
        )

        do {
            let result = try await registerClient.register(
                userId: uid,
                userToken: uid,  // user_token は user_id と同じ (既存フローと同様)
                items: [(metadata: metadata, imageData: data)]
            )
            switch result {
            case .success(let response):
                if response.success_count >= 1 {
                    return true
                }
                ToastManager.shared.show("登録に失敗しました")
                return false
            case .failure(let error):
                ToastManager.shared.show(error.errorDescription)
                return false
            }
        } catch {
            ToastManager.shared.show("通信エラーが発生しました")
            return false
        }
    }

    // MARK: - メタデータ自動推定 (端末内・LLM不要)

    static let categorySuggestions = [
        "Tシャツ", "シャツ", "ニット", "セーター", "パーカー", "スウェット", "カーディガン", "ブラウス",
        "パンツ", "ジーンズ", "ワイドパンツ", "スラックス", "チノパン", "ショートパンツ", "スカート", "スウェットパンツ"
    ]
    static let colorSuggestions = [
        "ブラック", "ホワイト", "グレー", "ネイビー", "ベージュ", "ブラウン",
        "カーキ", "ブルー", "グリーン", "レッド", "イエロー", "ピンク"
    ]

    private static let bottomsKeywords = [
        "パンツ", "ジーンズ", "デニム", "スラックス", "チノ", "スカート", "ショーツ", "ショートパンツ", "レギンス", "ボトム"
    ]

    static func inferItemType(from keyword: String) -> String {
        let lower = keyword.lowercased()
        if bottomsKeywords.contains(where: { lower.contains($0.lowercased()) }) {
            return ClothingCategory.bottoms.rawValue
        }
        return ClothingCategory.tops.rawValue
    }

    static func inferCategory(from keyword: String) -> String {
        // キーワードに含まれるカテゴリ候補があればそれを初期値にする (長いものを優先)
        let matched = categorySuggestions
            .filter { keyword.contains($0) }
            .max(by: { $0.count < $1.count })
        return matched ?? ""
    }

    private static let colorKeywordMap: [String: String] = [
        "白": "ホワイト", "ホワイト": "ホワイト", "オフホワイト": "ホワイト",
        "黒": "ブラック", "ブラック": "ブラック",
        "グレー": "グレー", "灰": "グレー",
        "ネイビー": "ネイビー", "紺": "ネイビー",
        "ベージュ": "ベージュ",
        "茶": "ブラウン", "ブラウン": "ブラウン",
        "カーキ": "カーキ", "オリーブ": "カーキ",
        "青": "ブルー", "ブルー": "ブルー",
        "緑": "グリーン", "グリーン": "グリーン",
        "赤": "レッド", "レッド": "レッド",
        "黄": "イエロー", "イエロー": "イエロー",
        "ピンク": "ピンク", "桃": "ピンク"
    ]

    static func inferColor(from keyword: String) -> String {
        // 長いキーワードを優先して一致させる (例: "オフホワイト" を "白" より優先)
        let matched = colorKeywordMap.keys
            .filter { keyword.contains($0) }
            .max(by: { $0.count < $1.count })
        if let matched { return colorKeywordMap[matched] ?? "" }
        return ""
    }

    // 標準パレット名 → 代表RGB (0...1)。平均色の最近傍で色名を推定する。
    private static let colorReference: [(name: String, r: Double, g: Double, b: Double)] = [
        ("ホワイト", 0.96, 0.96, 0.96),
        ("ブラック", 0.10, 0.10, 0.10),
        ("グレー", 0.55, 0.55, 0.55),
        ("ネイビー", 0.12, 0.16, 0.34),
        ("ベージュ", 0.87, 0.80, 0.68),
        ("ブラウン", 0.45, 0.30, 0.20),
        ("カーキ", 0.45, 0.47, 0.30),
        ("ブルー", 0.20, 0.40, 0.80),
        ("グリーン", 0.25, 0.55, 0.30),
        ("レッド", 0.75, 0.20, 0.20),
        ("イエロー", 0.90, 0.80, 0.25),
        ("ピンク", 0.90, 0.55, 0.65)
    ]

    /// 透過を除いた平均色から、標準パレットの最も近い色名を返す。
    static func detectColorName(from image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }

        let width = 32
        let height = 32
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var sumR = 0.0, sumG = 0.0, sumB = 0.0, count = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[i + 3]) / 255.0
            if alpha < 0.5 { continue }  // 透過部分は除外
            sumR += Double(pixels[i]) / 255.0
            sumG += Double(pixels[i + 1]) / 255.0
            sumB += Double(pixels[i + 2]) / 255.0
            count += 1
        }
        guard count > 0 else { return nil }

        let avgR = sumR / count, avgG = sumG / count, avgB = sumB / count

        var best: (name: String, dist: Double)?
        for ref in colorReference {
            let d = pow(avgR - ref.r, 2) + pow(avgG - ref.g, 2) + pow(avgB - ref.b, 2)
            if best == nil || d < best!.dist {
                best = (ref.name, d)
            }
        }
        return best?.name
    }
}
