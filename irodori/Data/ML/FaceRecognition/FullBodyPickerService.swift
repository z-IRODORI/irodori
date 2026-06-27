//
//  FullBodyPickerService.swift
//  irodori
//
//  顔写真（対象ユーザー）をもとに、フォトライブラリから
//  「対象ユーザーの顔が含まれる かつ 全身が写っている」写真をピックアップする。
//
//  パイプライン（各写真ごと）:
//    ① iOS Vision で顔検出
//    ② 検出した顔を EdgeFace で embedding 化し、対象ユーザーとのコサイン類似度で本人判定
//    ③ 既存 DetectHuman（Vision 全身検出）で全身が写っているか判定
//    ①〜③をすべて満たした写真を候補にする
//
//  重い処理（Core ML / Vision）が多いため、呼び出し側は Task.detached 等で
//  バックグラウンド実行し、progress は MainActor で受け取ること。
//

import Photos
import UIKit

struct FullBodyCandidate: Identifiable, Hashable {
    let id: String          // PHAsset.localIdentifier
    let image: UIImage
    let similarity: Float
}

final class FullBodyPickerService {
    private let faceEmbedder: FaceEmbedder?
    private let detectFace = DetectFace()
    private let detectHuman = DetectHuman()
    private let scanLimit: Int

    init(faceEmbedder: FaceEmbedder? = FaceEmbedder(), scanLimit: Int = 300) {
        self.faceEmbedder = faceEmbedder
        self.scanLimit = scanLimit
    }

    var isModelAvailable: Bool { faceEmbedder != nil }

    /// 顔写真（正方形）から対象ユーザーの embedding を抽出する
    func targetEmbedding(from faceImage: UIImage) -> [Float]? {
        guard let cg = faceImage.cgImage else { return nil }
        // 正方形に切り抜き済みでも、顔があれば顔領域を優先。無ければ画像全体。
        let faceCrop = detectFace.cropLargestFace(in: cg) ?? cg
        return faceEmbedder?.embedding(from: faceCrop)
    }

    func requestAuthorization() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let s = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return s == .authorized || s == .limited
        default:
            return false
        }
    }

    /// フォトライブラリを走査して全身候補を返す。progress は 0...1。
    func pickFullBodyPhotos(
        targetEmbedding: [Float],
        threshold: Float = 0.35,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> [FullBodyCandidate] {
        guard await requestAuthorization() else { return [] }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetched = PHAsset.fetchAssets(with: .image, options: options)
        guard fetched.count > 0 else { progress(1); return [] }

        var assets: [PHAsset] = []
        fetched.enumerateObjects { asset, _, stop in
            if assets.count >= self.scanLimit { stop.pointee = true; return }
            assets.append(asset)
        }

        let manager = PHImageManager.default()
        var candidates: [FullBodyCandidate] = []

        for (i, asset) in assets.enumerated() {
            progress(Double(i) / Double(assets.count))
            guard let ui = await Self.requestImage(asset, manager: manager, target: CGSize(width: 720, height: 720)),
                  let cg = ui.cgImage else { continue }

            // ① 顔検出
            let faces = detectFace.detectFaces(in: cg)
            guard !faces.isEmpty else { continue }

            // ② 本人判定（最大類似度）
            var best: Float = -1
            for box in faces {
                guard let crop = detectFace.squareCrop(cg, faceBox: box),
                      let emb = faceEmbedder?.embedding(from: crop) else { continue }
                best = max(best, FaceEmbedder.cosineSimilarity(targetEmbedding, emb))
            }
            guard best >= threshold else { continue }

            // ③ 全身判定（既存 DetectHuman を再利用）
            let isFullBody = (try? detectHuman.detect(inputCIImage: CIImage(cgImage: cg))) ?? false
            guard isFullBody else { continue }

            candidates.append(FullBodyCandidate(id: asset.localIdentifier, image: ui, similarity: best))
        }

        progress(1.0)
        return candidates.sorted { $0.similarity > $1.similarity }
    }

    // MARK: - PHImageManager async ラッパー

    private static func requestImage(_ asset: PHAsset, manager: PHImageManager, target: CGSize) async -> UIImage? {
        await withCheckedContinuation { cont in
            let opt = PHImageRequestOptions()
            opt.isSynchronous = false
            opt.deliveryMode = .highQualityFormat
            opt.resizeMode = .fast
            opt.isNetworkAccessAllowed = true
            var resumed = false
            manager.requestImage(for: asset, targetSize: target, contentMode: .aspectFit, options: opt) { image, info in
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                if resumed { return }
                resumed = true
                cont.resume(returning: image)
            }
        }
    }
}
