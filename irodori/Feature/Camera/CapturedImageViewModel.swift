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
    var mlErrorMessage: ErrorMessage?
    private let detectHuman = DetectHuman()
    let inputUIImage: UIImage
    init(inputUIImage: UIImage) {
        self.inputUIImage = inputUIImage
    }

    func onAppear() {
        #if targetEnvironment(simulator)
        isDetectHuman = true
        return
        #endif

        isLoading = true
        guard let inputCIImage = CIImage(image: inputUIImage) else {
            isLoading = false
            return
        }
        do {
            isDetectHuman = try detectHuman.detect(inputCIImage: inputCIImage)   // 処理時間めっちゃ短い
            if !isDetectHuman {
                mlErrorMessage = .init(title: MLError.notHuman.title, description: MLError.notHuman.errorDescription)
            }
        } catch {
            let mlError: MLError = error
            mlErrorMessage = .init(title: mlError.title, description: mlError.errorDescription)
        }
        isLoading = false
    }
}
