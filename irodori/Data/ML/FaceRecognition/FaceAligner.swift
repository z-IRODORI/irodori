//
//  FaceAligner.swift
//  irodori
//
//  EdgeFace は「アライメント済みの顔」で学習されているため、単純なクロップでは精度が出ない。
//  Vision の顔ランドマーク（両目・鼻・口）を ArcFace 標準5点テンプレートへ相似変換し、
//  112x112 に整列した顔を作る。これにより同一人物の embedding が安定し、本人判定が機能する。
//

import Vision
import UIKit

struct FaceAligner {
    // ArcFace 標準5点テンプレート（112x112 基準）
    private static let template: [CGPoint] = [
        CGPoint(x: 38.2946, y: 51.6963),  // 左目
        CGPoint(x: 73.5318, y: 51.5014),  // 右目
        CGPoint(x: 56.0252, y: 71.7366),  // 鼻
        CGPoint(x: 41.5493, y: 92.3655),  // 左口角
        CGPoint(x: 70.7299, y: 92.2041),  // 右口角
    ]
    private static let outputSize = 112

    /// 画像内の最大の顔を検出し、整列した 112x112 の顔 CGImage を返す
    func alignedFace(in cgImage: CGImage) -> CGImage? {
        guard let src = landmarks5(in: cgImage),
              let transform = Self.similarityTransform(from: src, to: Self.template) else { return nil }
        return Self.warp(cgImage, transform: transform, size: Self.outputSize)
    }

    // MARK: - 5点ランドマーク（画像ピクセル座標・左上原点）

    private func landmarks5(in cgImage: CGImage) -> [CGPoint]? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let face = request.results?.max(by: { $0.boundingBox.area < $1.boundingBox.area }),
              let lm = face.landmarks,
              let leftEye = lm.leftEye, let rightEye = lm.rightEye,
              let nose = lm.nose, let lips = lm.outerLips else { return nil }

        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let le = Self.center(leftEye, size)
        let re = Self.center(rightEye, size)
        let no = Self.center(nose, size)
        guard let (lmth, rmth) = Self.mouthCorners(lips, size) else { return nil }
        return [le, re, no, lmth, rmth]
    }

    private static func center(_ region: VNFaceLandmarkRegion2D, _ size: CGSize) -> CGPoint {
        let pts = region.pointsInImage(imageSize: size)  // 原点左下
        var sx: CGFloat = 0, sy: CGFloat = 0
        for p in pts { sx += p.x; sy += p.y }
        let n = CGFloat(max(pts.count, 1))
        return CGPoint(x: sx / n, y: size.height - sy / n)  // 左上原点へ
    }

    private static func mouthCorners(_ region: VNFaceLandmarkRegion2D, _ size: CGSize) -> (CGPoint, CGPoint)? {
        let pts = region.pointsInImage(imageSize: size)
        guard pts.count >= 2 else { return nil }
        let minX = pts.min { $0.x < $1.x }!
        let maxX = pts.max { $0.x < $1.x }!
        return (CGPoint(x: minX.x, y: size.height - minX.y),
                CGPoint(x: maxX.x, y: size.height - maxX.y))
    }

    // MARK: - 相似変換（Umeyama: scale + rotation + translation）

    private static func similarityTransform(from src: [CGPoint], to dst: [CGPoint]) -> CGAffineTransform? {
        guard src.count == dst.count, src.count >= 2 else { return nil }
        let n = CGFloat(src.count)
        var srcMean = CGPoint.zero, dstMean = CGPoint.zero
        for i in 0..<src.count {
            srcMean.x += src[i].x; srcMean.y += src[i].y
            dstMean.x += dst[i].x; dstMean.y += dst[i].y
        }
        srcMean.x /= n; srcMean.y /= n; dstMean.x /= n; dstMean.y /= n

        var a: CGFloat = 0, b: CGFloat = 0, srcVar: CGFloat = 0
        for i in 0..<src.count {
            let sx = src[i].x - srcMean.x, sy = src[i].y - srcMean.y
            let dx = dst[i].x - dstMean.x, dy = dst[i].y - dstMean.y
            a += sx * dx + sy * dy
            b += sx * dy - sy * dx
            srcVar += sx * sx + sy * sy
        }
        guard srcVar > 0 else { return nil }
        let sc = a / srcVar   // scale * cos
        let ss = b / srcVar   // scale * sin
        let tx = dstMean.x - (sc * srcMean.x - ss * srcMean.y)
        let ty = dstMean.y - (ss * srcMean.x + sc * srcMean.y)
        // x' = sc*x - ss*y + tx ; y' = ss*x + sc*y + ty （いずれも左上原点）
        return CGAffineTransform(a: sc, b: ss, c: -ss, d: sc, tx: tx, ty: ty)
    }

    // MARK: - ワープ描画（左上原点 UIKit 座標で）

    private static func warp(_ cgImage: CGImage, transform: CGAffineTransform, size: Int) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            ctx.cgContext.concatenate(transform)
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        return image.cgImage
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
