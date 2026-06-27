//
//  DetectFullBody.swift
//  irodori
//
//  「全身が写っているか」を姿勢推定で厳密に判定する。
//  VNDetectHumanRectangles（既存 DetectHuman）は「人物がいるか」までしか分からず、
//  上半身だけの写真も通してしまうため、足首/膝の検出で「足まで写っているか」を見る。
//

import Vision
import UIKit

struct DetectFullBody {
    /// 下半身（足首・膝）のキーポイントが検出されれば全身とみなす
    func isFullBody(in cgImage: CGImage, minConfidence: Float = 0.3) -> Bool {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return false
        }
        guard let obs = request.results?.first else { return false }

        // 「頭から膝くらいまで」写っていればOK（完璧な全身でなくてよい）。
        // 膝または足首のどちらかが見えていれば、膝以下まで写っているとみなす。
        // 頭部は本人判定（顔）で担保されているため、ここでは下半身の有無だけを見る。
        // 上半身だけ（膝・足首が無い）の写真は除外される。
        let lowerBody: [VNHumanBodyPoseObservation.JointName] = [
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
        ]
        return hasAny(obs, lowerBody, minConfidence)
    }

    private func hasAny(
        _ obs: VNHumanBodyPoseObservation,
        _ joints: [VNHumanBodyPoseObservation.JointName],
        _ minConfidence: Float
    ) -> Bool {
        for joint in joints {
            if let p = try? obs.recognizedPoint(joint), p.confidence >= minConfidence {
                return true
            }
        }
        return false
    }
}
