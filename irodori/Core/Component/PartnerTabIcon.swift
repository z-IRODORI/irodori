//
//  PartnerTabIcon.swift
//  irodori
//
//  タブの真ん中「相棒」のアイコン。相棒の絵 (PartnerIconImage と同じ画像) をそのまま使う。
//  タブのほかのアイコンは単色だが、相棒だけは色つきのまま、一回り大きく見せて目立たせる
//  (.alwaysOriginal)。タブには文字を付けない。
//

import UIKit

enum PartnerTabIcon {
    private static var cache: [String: UIImage] = [:]

    static func image(selected: Bool) -> UIImage {
        let name = assetName
        let key = "\(name)|\(selected)"
        if let hit = cache[key] { return hit }
        let image = render(name: name, selected: selected)
        cache[key] = image
        return image
    }

    /// 相棒の絵の名前 (PartnerIconImage と同じ決め方)
    private static var assetName: String {
        if let name = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerIconImage.rawValue),
           UIImage(named: name) != nil {
            return name
        }
        return "アヴァンギャルド・スター_icon"
    }

    private static func render(name: String, selected: Bool) -> UIImage {
        // ほかのタブのアイコン (約 25pt) より大きく。絵の背景は透明なので、枠も下地も付けずにそのまま置く。
        // 絵の周りの透明な余白を切り詰めてから、高さ 44pt に合わせる (相棒の絵は縦長)
        let height: CGFloat = 44   // 文字なしのタブなので、文字の分まで使って大きく
        guard let art = UIImage(named: name) else { return UIImage() }
        let box = opaqueBounds(of: art)
        let scale = height / box.height
        let size = CGSize(width: min(box.width * scale, 44), height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let drawRect = CGRect(x: (size.width - art.size.width * scale) / 2 - (box.midX - art.size.width / 2) * scale,
                                  y: -box.minY * scale,
                                  width: art.size.width * scale, height: art.size.height * scale)
            art.draw(in: drawRect)
        }
        return image.withRenderingMode(.alwaysOriginal)
    }

    /// 絵の中で透明でない部分の枠 (ポイント単位)。小さく描いてアルファを調べる
    private static func opaqueBounds(of image: UIImage) -> CGRect {
        let full = CGRect(origin: .zero, size: image.size)
        let w = 96, h = Int((CGFloat(w) * image.size.height / max(image.size.width, 1)).rounded())
        guard h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = image.cgImage else { return full }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return full }
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where px[(y * w + x) * 4 + 3] > 8 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return full }
        // CGContext は下が原点なので、上下を入れ替えて UIKit の座標に
        let sx = image.size.width / CGFloat(w), sy = image.size.height / CGFloat(h)
        return CGRect(x: CGFloat(minX) * sx, y: CGFloat(h - 1 - maxY) * sy,
                      width: CGFloat(maxX - minX + 1) * sx, height: CGFloat(maxY - minY + 1) * sy)
    }
}
