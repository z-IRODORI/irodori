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
    /// 被写体 (人物 / アイテム) を背景透過で切り抜く。
    /// - Parameter marginRatio: 切り抜きに持たせる余白。画像短辺に対する比率でマスクを
    ///   膨張させ、周囲に少し元背景の帯を残す (サーバー `segment_person_rgba` の
    ///   margin_ratio 相当)。0 で余白なし (アイテム切り抜きの既定)。
    static func removeBackgroundNoise(from image: UIImage, marginRatio: CGFloat = 0) async throws -> UIImage {
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

            let maskedCI = CIImage(cvPixelBuffer: maskedBuffer)
            let foreground: CIImage
            if marginRatio > 0 {
                // 余白を持たせて切り抜く: マスクを膨張し、周囲に元背景の帯を残す
                foreground = marginedForeground(
                    original: CIImage(cgImage: cgImage),
                    masked: maskedCI,
                    marginRatio: marginRatio
                )
            } else {
                // マスク直後に軽い輪郭スムージングをかけ、階段状のギザつきを均す
                foreground = smoothedAlpha(of: maskedCI, strength: 0.7)
            }
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

    /// 被写体マスクを余白ぶん膨張させ、その膨張マスクを「元画像」に適用して返す。
    /// サーバー `segment_person_rgba` の margin_ratio と同様、razor-tight を避けて
    /// 人物の周囲に少し元背景の帯を残す。
    /// - Parameters:
    ///   - original: 元画像 (余白部分に見える背景の供給元)
    ///   - masked: Vision の被写体マスク済み画像 (アルファがマスク)
    ///   - marginRatio: 画像短辺に対する余白比率
    private static func marginedForeground(original: CIImage, masked: CIImage, marginRatio: CGFloat) -> CIImage {
        let extent = masked.extent
        guard extent.width > 0, extent.height > 0 else { return masked }

        let minSide = min(extent.width, extent.height)
        let marginPx = max(4.0, min(60.0, minSide * marginRatio))

        // 被写体アルファをグレースケールマスクとして取り出す (RGB = A, A = 1)
        let alphaMask = masked.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ])

        // 余白ぶんマスクを膨張 + 軽いフェザー
        let dilatedMask = alphaMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: marginPx])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1.0, marginPx * 0.18)])
            .cropped(to: extent)

        // 膨張マスクを元画像に適用 → 人物 + 余白(周囲の元背景) を残し、外側は透明
        let clearBackground = CIImage(color: .clear).cropped(to: extent)
        return original.cropped(to: extent).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: clearBackground,
            kCIInputMaskImageKey: dilatedMask,
        ])
    }
}
