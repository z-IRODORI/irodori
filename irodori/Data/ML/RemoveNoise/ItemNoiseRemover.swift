//
//  ItemNoiseRemover.swift
//  irodori
//
//  クローゼットのアイテム画像から背景ノイズをオンデバイスで除去する。
//  Vision の被写体マスク (VNGenerateForegroundInstanceMaskRequest, iOS 17+) で
//  前景 = アイテムを切り出し、白背景に合成して返す。
//  アイテム画像は JPEG (白背景) として保存・表示されるため、透過ではなく白で塗り潰す。
//

import UIKit
import Vision
import CoreImage

enum ItemNoiseRemoverError: LocalizedError {
    case invalidImage
    case subjectNotFound
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "画像を読み込めませんでした"
        case .subjectNotFound: return "アイテムを検出できませんでした"
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

            let foreground = CIImage(cvPixelBuffer: maskedBuffer)
            let white = CIImage(color: .white).cropped(to: foreground.extent)
            let composed = foreground.composited(over: white)

            let context = CIContext()
            guard let output = context.createCGImage(composed, from: foreground.extent) else {
                throw ItemNoiseRemoverError.renderingFailed
            }
            return UIImage(cgImage: output)
        }.value
    }
}
