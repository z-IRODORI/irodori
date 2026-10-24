//
//  FilledAspectFrame.swift
//  irodori
//
//  決まった縦横比の枠に、画像を「はみ出した分を切り取って」敷き詰める。
//  .resizable().aspectRatio(3/4, contentMode: .fit) は画像の縦横比を無視して引き伸ばすため、
//  玄関カメラ (ラズパイ) の横長写真 (4:3) が縦長の枠で潰れて見えていた。
//

import SwiftUI

extension View {
    /// 縦横比 ratio (幅/高さ) の枠に、中身を scaledToFill して切り抜く。中身は .resizable() 済みの画像を渡す
    func filledAspectFrame(_ ratio: CGFloat) -> some View {
        Color.clear
            .aspectRatio(ratio, contentMode: .fit)
            .overlay { self.scaledToFill() }
            .clipped()
    }
}
