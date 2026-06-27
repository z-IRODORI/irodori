//
//  FullBodyPickerService.swift
//  irodori
//
//  顔写真（対象ユーザー）をもとに、フォトライブラリから
//  「対象ユーザーの顔が含まれる かつ 全身が写っている」写真をピックアップする。
//
//  パイプライン（各写真ごと）:
//    ① FaceAligner で顔検出＋アライメント（112x112に整列。EdgeFace の精度の要）
//    ② EdgeFace で embedding 化し、対象ユーザーとのコサイン類似度で本人判定（厳め）
//    ③ DetectFullBody（姿勢推定）で足首/膝を確認し「全身が写っているか」を判定
//
//  走査は直近 monthsBack ヶ月（既定12）に限定。重い処理が多いため呼び出し側は
//  バックグラウンドで実行し、progress は MainActor で受け取ること。
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
    private let aligner = FaceAligner()
    private let detectFullBody = DetectFullBody()
    private let monthsBack: Int
    private let scanLimit: Int

    init(faceEmbedder: FaceEmbedder? = FaceEmbedder(), monthsBack: Int = 12, scanLimit: Int = 2000) {
        self.faceEmbedder = faceEmbedder
        self.monthsBack = monthsBack
        self.scanLimit = scanLimit
    }

    var isModelAvailable: Bool { faceEmbedder != nil }

    /// 顔写真から対象ユーザーの embedding を抽出する（顔をアライメントしてから）
    func targetEmbedding(from faceImage: UIImage) -> [Float]? {
        guard let cg = faceImage.cgImage else { return nil }
        let aligned = aligner.alignedFace(in: cg) ?? cg
        return faceEmbedder?.embedding(from: aligned)
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

    /// 直近 monthsBack ヶ月の写真から全身候補を返す。progress は 0...1。
    /// threshold は本人判定のコサイン類似度のしきい値（高いほど厳しい）。
    func pickFullBodyPhotos(
        targetEmbedding: [Float],
        threshold: Float = 0.5,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> [FullBodyCandidate] {
        guard await requestAuthorization() else { return [] }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if let from = Calendar.current.date(byAdding: .month, value: -monthsBack, to: Date()) {
            options.predicate = NSPredicate(format: "creationDate >= %@", from as NSDate)
        }
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

            // ① 顔検出＋アライメント（顔が無ければ nil でスキップ）
            guard let aligned = aligner.alignedFace(in: cg),
                  let emb = faceEmbedder?.embedding(from: aligned) else { continue }

            // ② 本人判定（厳め）
            let sim = FaceEmbedder.cosineSimilarity(targetEmbedding, emb)
            guard sim >= threshold else { continue }

            // ③ 全身判定（足首/膝の姿勢で確認）
            guard detectFullBody.isFullBody(in: cg) else { continue }

            candidates.append(FullBodyCandidate(id: asset.localIdentifier, image: ui, similarity: sim))
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
