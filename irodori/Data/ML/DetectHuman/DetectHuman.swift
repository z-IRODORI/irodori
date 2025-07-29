//
//  DetectHuman.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/28.
//

import Vision
import UIKit

struct DetectHuman {
    let request: VNDetectHumanRectanglesRequest
    init() {
        request = VNDetectHumanRectanglesRequest()
        request.revision = VNDetectHumanRectanglesRequestRevision2
        request.upperBodyOnly = false  // 全身検出
    }

    /// 人間の検出有無に応じて Bool を返す
    func detect(inputCIImage: CIImage) throws(MLError) -> Bool {
        do {
            let handler = VNImageRequestHandler(ciImage: inputCIImage, options: [:])
            try handler.perform([request])
            guard let obs = request.results?.first as? VNDetectedObjectObservation else { return false }
            return obs.confidence > 0.6
        } catch {
            throw MLError.notHuman
        }
    }
}
