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
    static let palette: [Int: UIColor] = [
        0: .clear,        1: .brown,        2: .orange,      3: .cyan,
        4: .red,          5: .magenta,      6: .blue,        7: .purple,
        8: .yellow,       9: .darkGray,     10: .lightGray,  11: .green,
        12: .systemTeal,  13: .systemIndigo,14: .systemPink, 15: .systemBlue,
        16: .systemOrange,17: .systemPurple
    ]

    static func convertToUIImage(from multiArray: MLMultiArray,
                                 originalSize: CGSize) throws -> UIImage {

        let shape = multiArray.shape.map { $0.intValue }   // 例: [1,512,512] もしくは [C,H,W]
        guard shape.count == 3 else {
            throw NSError(domain: "SegmentationConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Expect 3-D tensor (N,C,H,W) or (C,H,W) without batch"])
        }

        // -----------------------------
        // 入力テンソル次元を解釈する
        // -----------------------------
        // (1, H, W) ならラベルマップ
        // (C, H, W) か (1, C, H, W) -> score マップ
        let channels    = shape[0]
        let height      = shape[1]
        let width       = shape[2]
        let count       = width * height
        let ptr         = UnsafeMutablePointer<Float32>(OpaquePointer(multiArray.dataPointer))
        let bytesPerPix = 4

        let bitmap = UnsafeMutablePointer<UInt8>.allocate(capacity: count * bytesPerPix)
        defer { bitmap.deallocate() }

        let isLabelMap = (channels == 1)

        for y in 0..<height {
            for x in 0..<width {

                // -------- 1) ラベルマップ ---------- //
                var labelID: Int = 0
                if isLabelMap {
                    let offset = channels*height*width + y*width + x          // (1,H,W) → フラット
                    labelID   = Int(ptr[offset])
                }
                // -------- 2) スコアマップ ----------- //
                else {
                    var maxScore: Float32 = -.greatestFiniteMagnitude
                    for c in 0..<channels {
                        let offset = c * height * width + y * width + x
                        let score  = ptr[offset]
                        if score > maxScore {
                            maxScore = score
                            labelID  = c
                        }
                    }
                }

                // -------- 色を書き込む --------------- //
                let rgba = rgbaComponents(from: colorFor(label: labelID))
                let idx  = (y * width + x) * bytesPerPix
                bitmap[idx    ] = UInt8(rgba[0] * 255)   // R
                bitmap[idx + 1] = UInt8(rgba[1] * 255)   // G
                bitmap[idx + 2] = UInt8(rgba[2] * 255)   // B
                bitmap[idx + 3] = UInt8(rgba[3] * 255 * 0.5)   // A
            }
        }

        // CGContext → UIImage
        guard let context = CGContext(data: bitmap,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * bytesPerPix,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cgImage = context.makeImage()
        else {
            throw NSError(domain: "SegmentationConverter",
                          code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "CGImage creation failed"])
        }

        return UIImage(cgImage: cgImage).resize(to: originalSize)
    }

    /// ラベルIDに対応する色を返す
    private static func colorFor(label: Int) -> UIColor {
        return palette[label] ?? UIColor(red: 0, green: 0, blue: 0, alpha: 0)  // 該当しない場合は透明
    }

    private static func rgbaComponents(from color: UIColor) -> [CGFloat] {
        // sRGB へ強制変換
        let rgbSpace = CGColorSpaceCreateDeviceRGB()
        let cgColor = color.cgColor

        let converted = cgColor.converted(to: rgbSpace, intent: .defaultIntent, options: nil) ?? cgColor

        let comps = converted.components ?? [0, 0, 0, 1]

        switch comps.count {
        case 4:                         // R G B A
            return comps
        case 2:                         // Gray, Alpha
            return [comps[0], comps[0], comps[0], comps[1]]
        default:                        // 想定外
            return [0, 0, 0, 1]
        }
    }
}
