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

        // 足首が見えていれば確実に全身（足先まで写る）
        let ankles: [VNHumanBodyPoseObservation.JointName] = [.leftAnkle, .rightAnkle]
        if hasAny(obs, ankles, minConfidence) { return true }

        // 足首が服等で隠れても、膝が十分下（画像下端付近）に見えていれば全身とみなす
        let knees: [VNHumanBodyPoseObservation.JointName] = [.leftKnee, .rightKnee]
        if let kneeY = lowestY(obs, knees, minConfidence), kneeY > 0.75 {
            return true
        }
        return false
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

    /// 指定関節のうち最も下にある点の y（Vision 正規化・原点左下 → 0=下,1=上 を 0=上,1=下 に直して返す）
    private func lowestY(
        _ obs: VNHumanBodyPoseObservation,
        _ joints: [VNHumanBodyPoseObservation.JointName],
        _ minConfidence: Float
    ) -> CGFloat? {
        var maxDownward: CGFloat?
        for joint in joints {
            if let p = try? obs.recognizedPoint(joint), p.confidence >= minConfidence {
                let downward = 1 - p.location.y  // 0=上, 1=下
                maxDownward = max(maxDownward ?? 0, downward)
            }
        }
        return maxDownward
    }
}
