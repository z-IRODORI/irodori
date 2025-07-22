//
//  SegmentationConverter.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/07/22.
//

import UIKit
import CoreML

struct SegmentationConverter {
    enum FashionItemType: Int, CaseIterable {
        case background = 0
        case hat
        case hair
        case sunglasses
        case upperClothes
        case skirt
        case pants
        case dress
        case belt
        case leftShoe
        case rightShoe
        case face
        case leftLeg
        case rightLeg
        case leftArm
        case rightArm
        case bag
        case scarf
    }
    static let fashionItems: [FashionItemType] = FashionItemType.allCases

    /// ラベルIDごとのカラーパレット
    ///
    /// Label: ,Left-leg,Right-leg,Left-arm,Right-arm,Bag,Scarf
    static let palette: [UIColor] = [
        .clear,           // Background
        .brown,           // Hat
        .orange,          // Hair
        .cyan,            // Sunglasses
        .red,             // Upper-clothes
        .magenta,         // Skirt
        .blue,            // Pants
        .purple,          // Dress
        .yellow,          // Belt
        .darkGray,        // Left-shoe
        .lightGray,       // Right-shoe
        .green,           // Face
        .systemTeal,      // Left-leg
        .systemIndigo,    // Right-leg
        .systemPink,      // Left-arm
        .systemBlue,      // Right-arm
        .systemOrange,    // Bag
        .systemPurple     // Scarf
    ]


    static func createOutputUIImage(output: ModelOutput) -> UIImage? {
        let resultArray = output.classLabelsShapedArray
        // 512*512 の要素がリストで格納される
        let outputColorList: [UIColor] = resultArray.scalars.map { labelIndex in
            if Int(labelIndex) == 0 {
                return .clear   // clear に withAlphaComponent をつけると少しグレーになるので個別に対応
            } else {
                return SegmentationConverter.palette[Int(labelIndex)]
            }
        }
        guard let cgImage = createCGImage(from: outputColorList) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// outputColorList -> CGImage
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

    /// ラベルが割り当てられた領域のみを抽出する
    ///
    /// Output: UIImage, 2値マスク画像（黒: 対象, 白: 背景）
    static func createMaskUIImage(from items: [FashionItemType], targetItems: [FashionItemType], width: Int = 512, height: Int = 512) -> UIImage {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        let bitmapData = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
        defer { bitmapData.deallocate() }

        for i in 0..<items.count {
            let offset = i * bytesPerPixel
            let black = 0, white = 255
            bitmapData[offset + 0] = UInt8(targetItems.contains(items[i]) ? black : white)
            bitmapData[offset + 1] = UInt8(targetItems.contains(items[i]) ? black : white)
            bitmapData[offset + 2] = UInt8(targetItems.contains(items[i]) ? black : white)
            bitmapData[offset + 3] = UInt8(1)
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

        let cgImage = context?.makeImage()
        return UIImage(cgImage: cgImage!)
    }
}
