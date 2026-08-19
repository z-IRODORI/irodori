//
//  AnalysisJobResponse.swift
//  irodori
//

import Foundation

/// POST/GET /api/analysis-jobs のレスポンス。
/// v2 コーデ解析のバックグラウンドジョブ状態 (常駐トースター UX 用)。
struct AnalysisJobResponse: Decodable, Hashable {
    let job_id: String
    let status: String              // "processing" | "completed" | "failed"
    let coordinate_id: String?
    let coordinate_image_path: String?
    let error: String?
}
