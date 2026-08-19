//
//  AnalysisJobStore.swift
//  irodori
//
//  v2 コーデ解析のバックグラウンドジョブ状態を全画面で共有するストア。
//  UserDefaults + Caches に永続化し、アプリ再起動後もトースターを復元して
//  ポーリングを再開する (完了 or キャンセルまで表示し続ける)。
//

import UIKit

@MainActor
@Observable
final class AnalysisJobStore {
    static let shared = AnalysisJobStore()

    enum Status: String, Codable {
        case processing
        case completed
        case failed
    }

    struct Job: Codable, Equatable {
        var jobId: String
        var status: Status
        var submittedAt: Date
        var coordinateId: String?
        var coordinateImageURL: String?
    }

    /// 進行中/完了直後のジョブ (nil = トースター非表示)
    private(set) var current: Job? {
        didSet { persist() }
    }
    /// トースターに出す撮影写真のサムネイル
    private(set) var thumbnail: UIImage?

    private let apiClient: AnalysisJobClientProtocol
    private var pollTask: Task<Void, Never>?

    private static let defaultsKey = "analysisJob.current"
    private static let thumbnailFileName = "analysis-job-thumb.jpg"
    private static let originalFileName = "analysis-job-original.jpg"
    private static let pollIntervalSeconds = 5
    private static let timeoutSeconds: TimeInterval = 300  // 5分で failed 扱い

    init(apiClient: AnalysisJobClientProtocol = AnalysisJobClient()) {
        self.apiClient = apiClient
    }

    // MARK: - ライフサイクル

    /// アプリ起動時の復元 (MainTabView .task から呼ぶ)。進行中ならポーリング再開。
    func restoreIfNeeded() {
        guard current == nil,
              let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let job = try? JSONDecoder().decode(Job.self, from: data) else { return }
        current = job
        thumbnail = loadImage(Self.thumbnailFileName)
        if job.status == .processing {
            startPolling()
        }
    }

    /// 解析ジョブを送信する。受付成功で true (呼び出し元は抽出画面を閉じてよい)。
    /// 進行中ジョブがある間は多重送信をブロックする。
    func submit(image: UIImage, cutoutImage: UIImage?) async -> Bool {
        if let job = current, job.status == .processing {
            ToastManager.shared.show("前の解析が完了するまでお待ちください")
            return false
        }
        guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
            ToastManager.shared.show("ユーザー情報が取得できませんでした")
            return false
        }

        saveImages(image)
        do {
            let result = try await apiClient.submit(uid: uid, image: image, cutoutImage: cutoutImage)
            switch result {
            case .success(let response):
                current = Job(jobId: response.job_id, status: .processing, submittedAt: Date())
                thumbnail = loadImage(Self.thumbnailFileName)
                startPolling()
                return true
            case .failure(let error):
                ToastManager.shared.show(error.errorDescription ?? "解析の受付に失敗しました")
                return false
            }
        } catch {
            ToastManager.shared.show("通信エラーが発生しました")
            return false
        }
    }

    /// トースターの ✕。ローカル追跡をやめるだけで、サーバー側の解析は完走し
    /// 結果はカレンダーに残る。
    func cancel() {
        pollTask?.cancel()
        pollTask = nil
        current = nil
        thumbnail = nil
        clearImages()
    }

    /// 完了トースタータップで結果を開いた後に呼ぶ (トースター消滅)
    func clearAfterOpeningResult() {
        cancel()
    }

    /// 失敗トースタータップで、保存してある元画像から再送信する
    func retry() async {
        guard let original = loadImage(Self.originalFileName) else {
            cancel()
            return
        }
        current = nil
        _ = await submit(image: original, cutoutImage: nil)
    }

    // MARK: - ポーリング

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollIntervalSeconds))
                guard let self, let job = self.current, job.status == .processing else { return }

                if Date().timeIntervalSince(job.submittedAt) > Self.timeoutSeconds {
                    self.current?.status = .failed
                    return
                }

                guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue),
                      let result = try? await self.apiClient.status(jobId: job.jobId, uid: uid),
                      case .success(let response) = result else { continue }

                switch response.status {
                case "completed":
                    self.current?.coordinateId = response.coordinate_id
                    self.current?.coordinateImageURL = response.coordinate_image_path
                    self.current?.status = .completed
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    return
                case "failed":
                    self.current?.status = .failed
                    return
                default:
                    continue
                }
            }
        }
    }

    // MARK: - 永続化 (UserDefaults + Caches)

    private func persist() {
        if let job = current, let data = try? JSONEncoder().encode(job) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
        }
    }

    private var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    private func saveImages(_ image: UIImage) {
        // サムネイル (トースター表示用) と元画像 (再試行用)
        let thumb = image.resizedToFit(longEdge: 240)
        try? thumb.jpegData(compressionQuality: 0.8)?
            .write(to: cachesDirectory.appendingPathComponent(Self.thumbnailFileName))
        try? image.jpegData(compressionQuality: 0.7)?
            .write(to: cachesDirectory.appendingPathComponent(Self.originalFileName))
    }

    private func loadImage(_ name: String) -> UIImage? {
        let url = cachesDirectory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func clearImages() {
        for name in [Self.thumbnailFileName, Self.originalFileName] {
            try? FileManager.default.removeItem(at: cachesDirectory.appendingPathComponent(name))
        }
    }
}
