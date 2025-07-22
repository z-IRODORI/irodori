//
//  SegmentationConverter.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/07/22.
//

import UIKit
import CoreML

struct SegmentationConverter {
    /// ラベルIDごとのカラーパレット
    ///
    /// Label: Background,Hat,Hair,Sunglasses,Upper-clothes,Skirt,Pants,Dress,Belt,Left-shoe,Right-shoe,Face,Left-leg,Right-leg,Left-arm,Right-arm,Bag,Scarf
    static let palette: [UIColor] = [
        .clear,
        .brown,
        .orange,
        .cyan,
        .red,
        .magenta,
        .blue,
        .purple,
        .yellow,
        .darkGray,
        .lightGray,
        .green,
        .systemTeal,
        .systemIndigo,
        .systemPink,
        .systemBlue,
        .systemOrange,
        .systemPurple
    ]


    static func createOutputUIImage(output: ModelOutput) -> UIImage? {
        let resultArray = output.classLabelsShapedArray
        // 512*512 の要素がリストで格納される
        let outputColorList: [UIColor] = resultArray.scalars.map { labelIndex in
            if Int(labelIndex) == 0 {
                return .clear   // clear に withAlphaComponent をつけると少しグレーになるので個別に対応
            } else {
                return SegmentationConverter.palette[Int(labelIndex)].withAlphaComponent(0.2)
            }
        }
        guard let cgImage = createCGImage(from: outputColorList) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func createCGImage(from colorArray: [UIColor], width: Int = 512, height: Int = 512) -> CGImage? {
        assert(colorArray.count == width * height, "colorArray size must be width * height")

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        let bitmapData = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
        defer { bitmapData.deallocate() }

        for i in 0..<colorArray.count {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            colorArray[i].getRed(&r, green: &g, blue: &b, alpha: &a)

            let offset = i * bytesPerPixel
            bitmapData[offset + 0] = UInt8(r * 255)
            bitmapData[offset + 1] = UInt8(g * 255)
            bitmapData[offset + 2] = UInt8(b * 255)
            bitmapData[offset + 3] = UInt8(a * 255)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        let context = CGContext(data: bitmapData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)

        return context?.makeImage()
    }
}
