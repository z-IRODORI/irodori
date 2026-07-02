//
//  ItemNoiseRemover.swift
//  irodori
//
//  クローゼットのアイテム画像から背景ノイズをオンデバイスで除去する。
//  Vision の被写体マスク (VNGenerateForegroundInstanceMaskRequest, iOS 17+) で
//  前景 = アイテムを切り出し、背景を透明 (アルファ) にして返す。
//  透過を保持するため、保存時は PNG でアップロードする (バックエンドは
//  受け取ったバイト列をそのまま保存し、コラージュ生成もアルファをそのまま利用する)。
//

import UIKit
import Vision
import CoreImage

enum ItemNoiseRemoverError: LocalizedError {
    case invalidImage
    case subjectNotFound
    case noTransparentBackground
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "画像を読み込めませんでした"
        case .subjectNotFound: return "アイテムを検出できませんでした"
        case .noTransparentBackground: return "先に「ノイズ除去」で背景を透明にしてください"
        case .renderingFailed: return "画像の処理に失敗しました"
        }
    }
}

enum ItemNoiseRemover {
    static func removeBackgroundNoise(from image: UIImage) async throws -> UIImage {
        let normalized = image.fixedOrientation()
        guard let cgImage = normalized.cgImage else { throw ItemNoiseRemoverError.invalidImage }

        // Vision の推論は重いためメインアクター外で実行する
        return try await Task.detached(priority: .userInitiated) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else {
                throw ItemNoiseRemoverError.subjectNotFound
            }

            let maskedBuffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: false
            )

            // マスク直後に軽い輪郭スムージングをかけ、階段状のギザつきを均す
            let foreground = smoothedAlpha(of: CIImage(cvPixelBuffer: maskedBuffer), strength: 0.7)
            let context = CIContext()
            guard let output = context.createCGImage(foreground, from: foreground.extent) else {
                throw ItemNoiseRemoverError.renderingFailed
            }
            return UIImage(cgImage: output)
        }.value
    }

    /// 切り抜き済み画像 (透過あり) の輪郭の凸凹をなめらかにする。
    /// セグメンテーション由来の階段状の輪郭を、アルファチャンネルの
    /// クローズ (凹み埋め) → 収縮 (黒フチ防止) → ぼかし (アンチエイリアス) で補正する。
    static func smoothEdges(of image: UIImage) async throws -> UIImage {
        let normalized = image.fixedOrientation()
        guard let cgImage = normalized.cgImage else { throw ItemNoiseRemoverError.invalidImage }

        // アルファチャンネルが無い (= 背景が透明でない) 画像は補正対象外
        switch cgImage.alphaInfo {
        case .premultipliedLast, .premultipliedFirst, .last, .first:
            break
        default:
            throw ItemNoiseRemoverError.noTransparentBackground
        }

        return try await Task.detached(priority: .userInitiated) {
            let output = smoothedAlpha(of: CIImage(cgImage: cgImage), strength: 1.0)
            let context = CIContext()
            guard let cg = context.createCGImage(output, from: output.extent) else {
                throw ItemNoiseRemoverError.renderingFailed
            }
            return UIImage(cgImage: cg)
        }.value
    }

    /// アルファチャンネルのみをなめらかにして元の色と再合成する。
    /// strength は補正半径の倍率 (1.0 = 標準)。半径は画像の長辺に比例させる。
    private static func smoothedAlpha(of source: CIImage, strength: CGFloat) -> CIImage {
        let extent = source.extent
        guard extent.width > 0, extent.height > 0 else { return source }

        let longEdge = max(extent.width, extent.height)
        let unit = max(1.0, longEdge / 512.0) * strength

        // アルファ → グレースケールマスク (RGB = A, A = 1)
        let alphaMask = source.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ])

        // クローズ (膨張 → 収縮) で階段の凹みを埋め、さらに収縮を強めて
        // ぼかしの縁が有効な色の内側に収まるようにする (黒フチ防止)
        let smoothMask = alphaMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 2.0 * unit])
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 3.5 * unit])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.2 * unit])
            .cropped(to: extent)

        let clearBackground = CIImage(color: .clear).cropped(to: extent)
        return source.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: clearBackground,
            kCIInputMaskImageKey: smoothMask,
        ])
    }
}
