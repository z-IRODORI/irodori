//
//  SegmentationViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/23.
//

import UIKit
import CoreML

@MainActor @Observable
final class SegmentationViewModel {
    enum ImageType: String, CaseIterable {
        case first = "1"
        case second = "2"
        case third = "3"
        case fourth = "4"

        var uiImage: UIImage {
            switch self {
            case .first: return .init(resource: .coordinate1)
            case .second: return .init(resource: .coordinate4)
            case .third: return .init(resource: .coordinate8)
            case .fourth: return .init(resource: .coordinate5)
            }
        }
    }
    var segmentTime = 0.0
    var inputUIImage: UIImage = .init(resource: .coordinate4)
    var outputUIImage: UIImage = .init(resource: .coordinate4)
    var topsUIImage: UIImage = .init()
    var bottomsUIImage: UIImage = .init()

    let model: Model?
    init() {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        do {
            self.model = try Model(configuration: config)
        } catch {
            self.model = nil
            print("モデルのロードまたは設定に失敗しました: \(error)")
        }
    }

    func segment() {
        Task {
            guard let pixelBuffer = inputUIImage.toCVPixelBuffer() else {
                throw NSError(domain: "ImageConversion", code: -1, userInfo: nil)
            }
            let input = ModelInput(image: pixelBuffer)
            guard let model else { return }
            let startTime = Date()
            let output = try await model.prediction(input: input)
            let items: [SegmentationConverter.FashionItemType] = output.classLabelsShapedArray.scalars.map { SegmentationConverter.fashionItems[Int($0)] }   // [.background, .background, ・・・]
            guard let outputUIImage = SegmentationConverter.createOutputUIImage(output: output) else { return }
            let topsMaskUIImage = SegmentationConverter.createMaskUIImage(from: items, targetItems: [.upperClothes, .leftArm, .rightArm]).resize(to: inputUIImage.size)
            let squareTopsUIImage = inputUIImage.mask(image: topsMaskUIImage).croppedNonTransparentToSquare512()!
            let bottomsMaskUIImage = SegmentationConverter.createMaskUIImage(from: items, targetItems: [.belt, .pants, .skirt]).resize(to: inputUIImage.size)
            let squareBottomsUIImage = inputUIImage.mask(image: bottomsMaskUIImage).croppedNonTransparentToSquare512()!

            self.outputUIImage = outputUIImage
            self.topsUIImage = squareTopsUIImage
            self.bottomsUIImage = squareBottomsUIImage

            segmentTime = -startTime.timeIntervalSinceNow   // s
        }
    }

    func tappedImageChangeButton(type: ImageType) {
        inputUIImage = type.uiImage
        outputUIImage = type.uiImage
        topsUIImage = .init()
        bottomsUIImage = .init()
        segmentTime = 0.0
    }
}
