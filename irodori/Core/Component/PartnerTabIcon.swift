//
//  PartnerTabIcon.swift
//  irodori
//
//  タブの真ん中「相棒」のアイコン。相棒の絵 (PartnerIconImage と同じ画像) を丸く切り抜き、
//  ピンクの輪で囲む。タブのほかのアイコンは単色だが、相棒だけは色つきのまま見せて目立たせる
//  (.alwaysOriginal)。選んでいるときは輪を太くする。
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
        let side: CGFloat = 30
        let ring: CGFloat = selected ? 2.5 : 1.5
        // ホームの「イチオシ」と同じピンク (RenewalTokens.accentPink #D81B60)
        let pink = UIColor(red: 0xD8 / 255, green: 0x1B / 255, blue: 0x60 / 255, alpha: 1)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { _ in
            let outer = CGRect(x: 0, y: 0, width: side, height: side)
            let inner = outer.insetBy(dx: ring + 1, dy: ring + 1)
            // 白い下地 + 絵 (丸く切り抜く)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: outer).fill()
            if let art = UIImage(named: name) {
                UIBezierPath(ovalIn: inner).addClip()
                art.draw(in: inner)
                UIGraphicsGetCurrentContext()?.resetClip()
            }
            // ピンクの輪
            let ringPath = UIBezierPath(ovalIn: outer.insetBy(dx: ring / 2, dy: ring / 2))
            ringPath.lineWidth = ring
            pink.setStroke()
            ringPath.stroke()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}
