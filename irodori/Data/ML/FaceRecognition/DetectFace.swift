//
//  DetectFace.swift
//  irodori
//
//  iOS Vision で顔を検出し、顔領域をクロップする（顔認識 EdgeFace への入力を作る）。
//

import Vision
import UIKit

struct DetectFace {
    /// 画像内の顔の bounding box（Vision 正規化座標・原点は左下）を返す
    func detectFaces(in cgImage: CGImage) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        guard let results = request.results else { return [] }
        return results.map { $0.boundingBox }
    }

    /// 顔 box（Vision 正規化座標）で CGImage を正方形にクロップ（周囲に余白を付ける）
    func squareCrop(_ cgImage: CGImage, faceBox: CGRect, padding: CGFloat = 0.3) -> CGImage? {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        // Vision は原点左下、CGImage は左上なので y を反転
        var rect = CGRect(
            x: faceBox.origin.x * w,
            y: (1 - faceBox.origin.y - faceBox.height) * h,
            width: faceBox.width * w,
            height: faceBox.height * h
        )

        // 余白を足して正方形化
        let pad = max(rect.width, rect.height) * padding
        rect = rect.insetBy(dx: -pad, dy: -pad)
        let side = max(rect.width, rect.height)
        rect = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard rect.width > 1, rect.height > 1 else { return nil }
        return cgImage.cropping(to: rect)
    }

    /// 画像から「最も大きい顔」を1つクロップして返す（顔写真入力の確認用）
    func cropLargestFace(in cgImage: CGImage) -> CGImage? {
        let boxes = detectFaces(in: cgImage)
        guard let largest = boxes.max(by: { $0.width * $0.height < $1.width * $1.height }) else { return nil }
        return squareCrop(cgImage, faceBox: largest)
    }
}
