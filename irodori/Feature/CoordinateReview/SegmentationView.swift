//
//  SegmentationView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/07/22.
//

import SwiftUI
import CoreML

struct SegmentationView: View {
    let ViewModel: SegmentationViewModel = .init()

    var body: some View {
        VStack(spacing: 24) {
            Button(action: {
                ViewModel.segment()
            }) {
                Text("Segmentation")
            }

            ZStack {
                Image(uiImage: ViewModel.inputUIImage)
                    .resizable()
                Image(uiImage: ViewModel.outputUIImage)
                    .resizable()
            }
            .aspectRatio(3/4, contentMode: .fit)
        }
    }
}

#Preview {
    SegmentationView()
}

@MainActor @Observable
final class SegmentationViewModel {
    var inputUIImage: UIImage = .init(resource: .coordinate1)
    var outputUIImage: UIImage = .init(resource: .coordinate1)
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
            print("start Segmentation")
            guard let pixelBuffer = inputUIImage.toCVPixelBuffer() else {
                throw NSError(domain: "ImageConversion", code: -1, userInfo: nil)
            }
            let input = ModelInput(image: pixelBuffer)
            guard let model else { return }
            let output = try await model.prediction(input: input)
            guard let outputUIImage = SegmentationConverter.createOutputUIImage(output: output) else { return }
            let segmentationImage: UIImage = outputUIImage.resize(to: inputUIImage.size)
            self.outputUIImage = segmentationImage
        }
    }
}
