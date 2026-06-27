//
//  FaceEmbedder.swift
//  irodori
//
//  EdgeFace (Core ML) で顔画像から embedding を取り出し、本人判定に使う。
//  入力: 112x112 RGB（前処理 scale=1/127.5, bias=-1 はモデルに埋め込み済み）
//  出力: embedding ベクトル → L2正規化してコサイン類似度で比較する。
//
//  EdgeFace.mlpackage は Xcode でビルド時に EdgeFace.mlmodelc にコンパイルされる。
//  ここでは自動生成クラスに依存せず Bundle から動的ロードする（統合状況に左右されず
//  ビルドが通る。モデルが無ければ init で nil）。
//

import CoreML
import UIKit

final class FaceEmbedder {
    private let model: MLModel
    private let inputName: String
    private let outputName: String

    init?() {
        guard let url = Bundle.main.url(forResource: "EdgeFace", withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: url) else {
            print("[FaceEmbedder] EdgeFace.mlmodelc が見つかりません（Xcode ターゲット未参加の可能性）")
            return nil
        }
        self.model = model
        // 入出力名はモデル記述から取得（変換時 image / embedding を想定しつつ堅牢に）
        self.inputName = model.modelDescription.inputDescriptionsByName.keys.first ?? "image"
        self.outputName = model.modelDescription.outputDescriptionsByName.keys.first ?? "embedding"
    }

    /// 顔のクロップ画像 → L2正規化済み embedding
    func embedding(from faceCGImage: CGImage) -> [Float]? {
        guard let pixelBuffer = Self.makePixelBuffer(from: faceCGImage, side: 112) else { return nil }
        guard let input = try? MLDictionaryFeatureProvider(
            dictionary: [inputName: MLFeatureValue(pixelBuffer: pixelBuffer)]
        ) else { return nil }
        guard let out = try? model.prediction(from: input),
              let arr = out.featureValue(for: outputName)?.multiArrayValue else { return nil }

        var vec = [Float](repeating: 0, count: arr.count)
        for i in 0..<arr.count { vec[i] = arr[i].floatValue }
        return Self.l2normalize(vec)
    }

    /// L2正規化済みベクトル同士のコサイン類似度（= 内積）
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return -1 }
        var dot: Float = 0
        for i in 0..<a.count { dot += a[i] * b[i] }
        return dot
    }

    // MARK: - helpers

    private static func l2normalize(_ v: [Float]) -> [Float] {
        var norm: Float = 0
        for x in v { norm += x * x }
        norm = norm.squareRoot()
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }

    /// CGImage を side×side の 32BGRA CVPixelBuffer に描画（Core ML の Image 入力用）
    private static func makePixelBuffer(from cgImage: CGImage, side: Int) -> CVPixelBuffer? {
        let attrs: CFDictionary = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ] as CFDictionary
        var pb: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, side, side, kCVPixelFormatType_32BGRA, attrs, &pb)
        guard status == kCVReturnSuccess, let buffer = pb else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        return buffer
    }
}
