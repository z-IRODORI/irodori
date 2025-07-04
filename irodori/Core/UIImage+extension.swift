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
