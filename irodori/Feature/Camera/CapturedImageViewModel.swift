//
//  CapturedImageViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/28.
//

import Foundation
import UIKit

@MainActor @Observable
final class CapturedImageViewModel {
    var isLoading: Bool = false
    var isDetectHuman: Bool = false
    private let detectHuman = DetectHuman()
    let inputUIImage: UIImage
    init(inputUIImage: UIImage) {
        self.inputUIImage = inputUIImage
    }

    func onAppear() {
        isLoading = true
        guard let inputCIImage = CIImage(image: inputUIImage) else {
            isLoading = false
            return
        }
        isDetectHuman = detectHuman.detect(inputCIImage: inputCIImage)   // 処理時間めっちゃ短い
        isLoading = false
    }
}
