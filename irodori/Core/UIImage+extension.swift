//
//  UIImage+extension.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/03.
//

import UIKit

extension UIImage {
    /// 画像を指定サイズに中心トリミングする
    func crop(to size: CGSize) -> UIImage? {
        // UIImageからCGImageを取得できない場合はnilを返す
        guard let cgImage = self.cgImage else { return nil }

        // UIImageのピクセルサイズを取得する
        // （.sizeはポイントベースのため、必要に応じてscaleも考慮します）
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // トリミングしたい範囲(中心で切り抜き)を計算
        let posX = (width/2) - (size.width/2)
        let posY = (height/2) - (size.height/2)
        let cropRect = CGRect(x: posX, y: posY, width: size.width, height: size.height)

        // cropRectの範囲でCGImageを切り抜く
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }

        // トリミング後のUIImageを生成して返す
        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: self.imageOrientation)
    }

    var correctOrientation: UIImage {
        let ciContext = CIContext()
        var newImage = UIImage()
        switch self.imageOrientation.rawValue {
         case 1:
            guard let orientedCIImage = CIImage(image: self)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { print("Image rotation failed."); return self}
            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: self)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { print("Image rotation failed."); return self}
           newImage = UIImage(cgImage: cgImage)
        default:
           newImage = self
        }
        return newImage
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

extension UIImage {
    func toCVPixelBuffer(width: Int = 512, height: Int = 512) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32BGRA,
                            attrs,
                            &pixelBuffer)

        guard let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return nil
        }

        context.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }

    func resize(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? self
    }

    /// 長辺が longEdge px を超える場合のみ、アスペクト比を保ってピクセルベースで縮小する
    func resizedToFit(longEdge: CGFloat) -> UIImage {
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > longEdge else { return self }

        let ratio = longEdge / longest
        let newSize = CGSize(width: floor(pixelWidth * ratio), height: floor(pixelHeight * ratio))
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? self
    }
}

extension UIImage {
    func mask(image: UIImage?) -> UIImage {
        if let maskRef = image?.cgImage,
           let ref = cgImage,
           let mask = CGImage(maskWidth: maskRef.width,
                               height: maskRef.height,
                               bitsPerComponent: maskRef.bitsPerComponent,
                               bitsPerPixel: maskRef.bitsPerPixel,
                               bytesPerRow: maskRef.bytesPerRow,
                               provider: maskRef.dataProvider!,
                               decode: nil,
                               shouldInterpolate: false),
            let output = ref.masking(mask) {
            return UIImage(cgImage: output)
        }
        return self
    }
}

extension UIImage {
    /// 透明余白をトリムし、元画像と同じ長辺の正方形キャンバス中央にフィットさせて返す (透過保持)。
    /// アイテム画像編集で被写体が隅に小さく残った場合に、被写体が画像領域いっぱいに
    /// 写るよう正規化する。完全に透明な画像は nil を返す。
    func normalizedToContentSquare(alphaThreshold: UInt8 = 8) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        guard width > 0, height > 0,
              let data = calloc(height * width, bytesPerPixel) else { return nil }
        defer { free(data) }

        guard let context = CGContext(data: data,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.assumingMemoryBound(to: UInt8.self)

        // アルファが閾値を超える画素のバウンディングボックスを求める
        var minX = width, maxX = -1
        var minY = height, maxY = -1
        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                if pixels[rowOffset + x * bytesPerPixel + 3] > alphaThreshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }   // 全透明

        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }

        // 元画像の長辺 (ピクセル) を一辺とする正方形に、アスペクト比を保って中央フィット
        let side = CGFloat(max(width, height))
        let scaleFactor = min(side / cropRect.width, side / cropRect.height)
        let drawSize = CGSize(width: cropRect.width * scaleFactor,
                              height: cropRect.height * scaleFactor)
        let drawOrigin = CGPoint(x: (side - drawSize.width) / 2,
                                 y: (side - drawSize.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let cropped = UIImage(cgImage: croppedCG)
        return renderer.image { _ in
            cropped.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
    }
}

extension UIImage {
    /// 不透明領域をクロップし、512×512の中央に配置して返す
    func croppedNonTransparentToSquare512() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let data = calloc(height * width, bytesPerPixel) else { return nil }
        defer { free(data) }

        guard let context = CGContext(data: data,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let pixelBuffer = data.assumingMemoryBound(to: UInt8.self)

        // 最小矩形の初期化
        var minX = width, maxX = 0
        var minY = height, maxY = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = pixelBuffer[offset + 0]
                let g = pixelBuffer[offset + 1]
                let b = pixelBuffer[offset + 2]
                let alpha = pixelBuffer[offset + 3]

                // 白&透明 以外の領域を求める。
                // 旧実装は `alpha == 1` (=ちょうど 1/255) の画素しか拾っておらず、
                // アンチエイリアス縁の希少な画素頼みでバウンディングボックスが
                // 欠けてアイテムが見切れることがあった。不透明画素全体で判定する
                if !(r == 255 && g == 255 && b == 255) && (alpha > 0) {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }

        guard minX < maxX && minY < maxY else {
            print("透明領域のみの画像です")
            return nil
        }

        // クロップする矩形
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
        let croppedImage = UIImage(cgImage: croppedCG, scale: self.scale, orientation: self.imageOrientation)

        // 512×512 のキャンバスに中央配置（引き伸ばしなし）
        let targetSize: CGFloat = 512
        let canvasSize = CGSize(width: targetSize, height: targetSize)

        let scaleFactor = min(targetSize / cropRect.width, targetSize / cropRect.height)
        let drawSize = CGSize(width: CGFloat(cropRect.width) * scaleFactor,
                              height: CGFloat(cropRect.height) * scaleFactor)
        let drawOrigin = CGPoint(x: (targetSize - drawSize.width) / 2,
                                 y: (targetSize - drawSize.height) / 2)

        UIGraphicsBeginImageContextWithOptions(canvasSize, false, self.scale)
        croppedImage.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return result
    }
}

