//
//  PersonCollageEngine.swift
//  irodori
//
//  コーデコラージュ (人物切り抜きコラージュ) の端末内エンジン。
//  サーバー (irodori-api collage_service.py) の合成ロジックを端末に移植し、
//  切り抜き → 初期レイアウト → 編集 → 合成 をすべてオンデバイスで完結させる。
//   - 切り抜き: 透過画像はそのまま、不透過画像は Vision (ItemNoiseRemover) で人物切り抜き
//   - レイアウト: IRODORI ロゴを最上部固定、人数に応じた段組で人物を配置 (サーバーと同仕様)
//   - ステッカー: 人物アルファを膨張させた白縁を敷く (サーバー _make_sticker 相当)
//   - 合成: 1080x1440 キャンバスに 背景色 → ロゴ → 人物(z順・回転・影) を描画
//
//  座標系はサーバーの layout と同じ「キャンバス比の正規化値 (左上原点 0-1)」。
//  w/h はステッカー画像 (白縁込み) の外接サイズ、r は中心回りの回転 (度)。
//

import UIKit
import CoreImage

/// 編集可能なレイヤーの変換状態。画像本体は持たず id で引く (undo スナップショットを軽くするため)
struct PersonCollageLayer: Identifiable, Equatable {
    let id: String
    var x: Double       // 正規化 左上 x
    var y: Double       // 正規化 左上 y
    var w: Double       // 正規化 幅
    var h: Double       // 正規化 高さ
    var r: Double       // 回転 (度, 時計回り, 中心回り)
    var z: Int          // 重なり順 (大きいほど前面)
    var hidden: Bool = false
}

enum PersonCollageEngine {
    static let canvasSize = CGSize(width: 1080, height: 1440)

    // サーバー collage_service.py と同じレイアウト定数
    private static let logoWidthRatio: CGFloat = 0.56
    private static let logoTopMarginRatio: CGFloat = 0.04
    private static let baseYRatio: CGFloat = 0.965
    private static let logoGapRatio: CGFloat = 0.012
    private static let packGap: CGFloat = 4

    // MARK: - 切り抜き準備

    /// 入力画像データから人物レイヤー (透過・アルファ BBox トリム済み) を作る。
    /// 透過画素を持つ画像は切り抜き済みとみなしそのまま使い (サーバーと同じ判定)、
    /// 不透過画像は Vision の被写体マスクで人物を切り抜く。人物が見つからない画像は除外。
    static func prepareCutouts(from datas: [Data]) async -> [UIImage] {
        var cutouts: [UIImage] = []
        for data in datas {
            guard let image = UIImage(data: data)?.fixedOrientation() else { continue }
            if hasTransparentPixels(image) {
                if let trimmed = trimmedToAlphaBBox(image) {
                    cutouts.append(trimmed)
                }
                continue
            }
            // サーバー segment_person_rgba と同じ margin_ratio=0.045 で余白を残す
            guard let cut = try? await ItemNoiseRemover.removeBackgroundNoise(from: image, marginRatio: 0.045),
                  let trimmed = trimmedToAlphaBBox(cut) else {
                continue
            }
            cutouts.append(trimmed)
        }
        return cutouts
    }

    // MARK: - ステッカー化 (白縁)

    /// 人物切り抜きに白縁を付けたステッカー画像を作る (サーバー _make_sticker 相当)。
    /// アルファを硬化 → 白縁ぶん膨張 → 軽いアンチエイリアスで、くっきりした縁にする。
    static func makeSticker(from cutout: UIImage) -> UIImage {
        guard let cgImage = cutout.cgImage else { return cutout }
        let height = CGFloat(cgImage.height)
        let borderPx = min(24, max(6, height * 0.012))
        let pad = borderPx * 2 + 8

        let source = CIImage(cgImage: cgImage)
            .transformed(by: CGAffineTransform(translationX: pad, y: pad))
        let extent = CGRect(x: 0, y: 0,
                            width: CGFloat(cgImage.width) + pad * 2,
                            height: height + pad * 2)

        // アルファ → グレースケールマスク (RGB = A)
        let alphaMask = source.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ]).cropped(to: extent)

        // 硬化 (フェザーの滲みを除去) → 白縁ぶん膨張 → 最小限のブラーでアンチエイリアス
        let borderMask = alphaMask
            .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.5])
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: borderPx])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.6])
            .cropped(to: extent)

        let clear = CIImage(color: .clear).cropped(to: extent)
        let white = CIImage(color: .white).cropped(to: extent)
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: clear,
                kCIInputMaskImageKey: borderMask,
            ])

        let output = source.composited(over: white)
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: extent) else { return cutout }
        return UIImage(cgImage: cg)
    }

    // MARK: - 初期レイアウト

    /// 人数に応じた段組でステッカーを配置した初期レイアウトを作る (サーバー _arrange_people 移植)。
    /// ロゴ帯の下 〜 キャンバス下端 96.5% の範囲に、足元を段ごとのベースラインに揃えて置く。
    static func defaultLayout(stickers: [UIImage], seed: UInt64) -> [PersonCollageLayer] {
        guard !stickers.isEmpty else { return [] }
        var rng = SplitMix64(seed: seed)
        let W = canvasSize.width
        let H = canvasSize.height

        let peopleTop = logoBottomY() + H * logoGapRatio
        let baseY = H * baseYRatio
        let availH = max(1, baseY - peopleTop)

        let n = stickers.count
        let rows = n <= 3 ? 1 : (n <= 8 ? 2 : 3)

        // 段ごとの人数 (余りは前 = 下の段へ)
        var counts = Array(repeating: n / rows, count: rows)
        for i in 0..<(n % rows) { counts[rows - 1 - i] += 1 }

        // 段間の縦の重なり係数 (サーバー V=0.72)
        let figH: CGFloat = rows == 1 ? availH : availH / (1.0 + 0.72 * CGFloat(rows - 1))

        var order = Array(0..<n)
        rng.shuffle(&order)

        var layers: [PersonCollageLayer] = []
        var z = 0
        var globalLeft = CGFloat.greatestFiniteMagnitude
        var globalRight = -CGFloat.greatestFiniteMagnitude
        var pi = 0

        for row in 0..<rows {
            let count = counts[row]
            guard count > 0 else { continue }
            let members = Array(order[pi..<(pi + count)])
            pi += count

            let baseline = rows == 1
                ? baseY
                : peopleTop + figH + CGFloat(row) * (availH - figH) / CGFloat(rows - 1)

            // 各メンバーのサイズ・角度 (サーバーと同じゆらぎ)
            struct Placement { let index: Int; let w: CGFloat; let h: CGFloat; let angle: Double }
            var placements: [Placement] = []
            for (k, idx) in members.enumerated() {
                let signed = Double(k) - Double(count - 1) / 2.0
                let angle = -(signed * 4.0) + rng.uniform(-3.0, 3.0)
                let h = figH * rng.uniform(0.94, 1.06)
                let aspect = stickers[idx].size.width / max(1, stickers[idx].size.height)
                placements.append(Placement(index: idx, w: h * aspect, h: h, angle: angle))
            }

            // 回転後の外接幅で左→右に詰める
            func rotatedSize(_ p: Placement) -> CGSize {
                let rad = CGFloat(abs(p.angle)) * CGFloat.pi / 180
                let cosR = cos(rad)
                let sinR = sin(rad)
                let rw: CGFloat = p.w * cosR + p.h * sinR
                let rh: CGFloat = p.w * sinR + p.h * cosR
                return CGSize(width: rw, height: rh)
            }
            var totalW = placements.reduce(0) { $0 + rotatedSize($1).width } + packGap * CGFloat(count - 1)
            let usableW = W * (rows == 1 ? 0.98 : 0.92)

            // 入りきらなければ全員を縮小
            var scale: CGFloat = 1.0
            if totalW > usableW { scale = usableW / totalW }
            placements = placements.map {
                Placement(index: $0.index, w: $0.w * scale, h: $0.h * scale, angle: $0.angle)
            }
            totalW *= scale

            // 交互の段を横ずらし (前段が後段の隙間に入る)
            let avgW = placements.reduce(0) { $0 + $1.w } / CGFloat(count)
            let stagger = (rows > 1 && row % 2 == 1) ? avgW * 0.30 : 0

            var x = (W - totalW) / 2 + stagger
            for p in placements {
                let rot = rotatedSize(p)
                // 足元 (回転後の下端) をベースラインに揃える
                let centerY = baseline - rot.height / 2
                let centerX = x + rot.width / 2
                let left = centerX - p.w / 2
                let top = centerY - p.h / 2
                layers.append(PersonCollageLayer(
                    id: "person-\(p.index)",
                    x: Double(left / W),
                    y: Double(top / H),
                    w: Double(p.w / W),
                    h: Double(p.h / H),
                    r: p.angle,
                    z: z
                ))
                z += 1
                globalLeft = min(globalLeft, x)
                globalRight = max(globalRight, x + rot.width)
                x += rot.width + packGap
            }
        }

        // 全体の見た目を水平センタリング
        if globalRight > globalLeft {
            let shift = Double((W / 2 - (globalLeft + globalRight) / 2) / W)
            for i in layers.indices { layers[i].x += shift }
        }
        return layers
    }

    // MARK: - 合成

    /// 現在のレイヤー配置でコラージュ PNG を合成する。
    /// 背景色 → IRODORI ロゴ (上部固定・人物と重ねない) → 人物ステッカー (z順・回転・影)。
    static func compose(
        layers: [PersonCollageLayer],
        stickers: [String: UIImage],
        background: UIColor
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            background.setFill()
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            // ロゴ (背景色とのコントラストが高い方を選ぶ)
            if let logo = logoImage(for: background) {
                let w = canvasSize.width * logoWidthRatio
                let h = w * logo.size.height / max(1, logo.size.width)
                let rect = CGRect(x: (canvasSize.width - w) / 2,
                                  y: canvasSize.height * logoTopMarginRatio,
                                  width: w, height: h)
                logo.draw(in: rect)
            }

            for layer in layers.sorted(by: { $0.z < $1.z }) where !layer.hidden {
                guard let sticker = stickers[layer.id] else { continue }
                let w = CGFloat(layer.w) * canvasSize.width
                let h = CGFloat(layer.h) * canvasSize.height
                let centerX = (CGFloat(layer.x) + CGFloat(layer.w) / 2) * canvasSize.width
                let centerY = (CGFloat(layer.y) + CGFloat(layer.h) / 2) * canvasSize.height

                cg.saveGState()
                cg.translateBy(x: centerX, y: centerY)
                cg.rotate(by: CGFloat(layer.r) * .pi / 180)
                // ドロップシャドウ (サーバーと同程度: 縁サイズ比例のオフセット + ぼかし)
                let borderPx = min(16, max(6, h * 0.012))
                cg.setShadow(
                    offset: CGSize(width: borderPx * 0.8, height: borderPx * 1.4),
                    blur: borderPx + 6,
                    color: UIColor.black.withAlphaComponent(0.4).cgColor
                )
                sticker.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                cg.restoreGState()
            }
        }
    }

    /// 背景色に対しコントラスト比が高いロゴ (white/black) を返す (サーバー _pick_logo_variant 移植)
    static func logoImage(for background: UIColor) -> UIImage? {
        UIImage(named: preferredLogoName(for: background))
    }

    static func preferredLogoName(for background: UIColor) -> String {
        let l = relativeLuminance(background)
        let contrastWhite = 1.05 / (l + 0.05)
        let contrastBlack = (l + 0.05) / 0.05
        return contrastWhite >= contrastBlack ? "logo-white" : "logo-black"
    }

    /// ロゴ帯の下端 y (キャンバス px)。人物はこれより上に置かない
    static func logoBottomY() -> CGFloat {
        let top = canvasSize.height * logoTopMarginRatio
        guard let logo = UIImage(named: "logo-black") else { return top }
        let h = canvasSize.width * logoWidthRatio * logo.size.height / max(1, logo.size.width)
        return top + h
    }

    private static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    // MARK: - アルファ処理ユーティリティ

    /// 透過画素を持つか (縮小してアルファ最小値を調べる。サーバー alpha_min < 250 判定と同義)
    static func hasTransparentPixels(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        switch cgImage.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            break
        }
        guard let alpha = alphaBytes(of: cgImage, maxLongEdge: 128) else { return false }
        return alpha.pixels.contains { $0 < 250 }
    }

    /// アルファの外接 BBox でトリムする (完全透明の余白を落とす)
    static func trimmedToAlphaBBox(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage,
              let alpha = alphaBytes(of: cgImage, maxLongEdge: 512) else { return image }

        var minX = alpha.width, minY = alpha.height, maxX = -1, maxY = -1
        for y in 0..<alpha.height {
            for x in 0..<alpha.width where alpha.pixels[y * alpha.width + x] > 8 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }  // 全透明

        // 縮小マスク座標 → 元画像座標 (1px マージンで切りすぎを防ぐ)
        let sx = CGFloat(cgImage.width) / CGFloat(alpha.width)
        let sy = CGFloat(cgImage.height) / CGFloat(alpha.height)
        let rect = CGRect(
            x: max(0, (CGFloat(minX) - 1) * sx),
            y: max(0, (CGFloat(minY) - 1) * sy),
            width: min(CGFloat(cgImage.width), (CGFloat(maxX - minX) + 3) * sx),
            height: min(CGFloat(cgImage.height), (CGFloat(maxY - minY) + 3) * sy)
        ).integral
        guard let cropped = cgImage.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped)
    }

    /// CGImage のアルファチャンネルを (必要なら縮小して) バイト列で取り出す
    private static func alphaBytes(
        of cgImage: CGImage, maxLongEdge: Int
    ) -> (pixels: [UInt8], width: Int, height: Int)? {
        let scale = min(1.0, CGFloat(maxLongEdge) / CGFloat(max(cgImage.width, cgImage.height)))
        let w = max(1, Int(CGFloat(cgImage.width) * scale))
        let h = max(1, Int(CGFloat(cgImage.height) * scale))
        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let context = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (pixels, w, h)
    }
}

// MARK: - シード付き乱数 (配置の再現用)

/// SplitMix64。seed が同じなら同じ配置を再現する (サーバーの seed 付き random.Random 相当)
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func uniform(_ low: Double, _ high: Double) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return low + (high - low) * unit
    }

    mutating func uniform(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
        CGFloat(uniform(Double(low), Double(high)))
    }

    mutating func shuffle(_ array: inout [Int]) {
        guard array.count > 1 else { return }
        for i in stride(from: array.count - 1, to: 0, by: -1) {
            let j = Int(next() % UInt64(i + 1))
            array.swapAt(i, j)
        }
    }
}
