//
//  TryOnViewModel.swift
//  irodori
//
//  試着画面の状態管理。キャッシュ優先 → 生成 API → 結果キャッシュ保存。
//

import SwiftUI
import UIKit

/// 失敗をユーザー文言と挙動 (再試行可否 / 顔写真変更の提案) に変換したもの
struct TryOnFailure: Equatable {
    let code: String
    let message: String
    let allowsRetry: Bool
    let suggestsFaceChange: Bool
}

@Observable @MainActor
final class TryOnViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case success(UIImage, fromCache: Bool)
        case failure(TryOnFailure)
    }

    let source: TryOnSource
    private let client: TryOnClientProtocol
    /// Preview / Sandbox 用: FaceImageStore を経由せず顔データを注入する
    private let faceDataOverride: Data?
    private(set) var phase: Phase = .idle
    private(set) var didSaveToPhotos = false
    private var generationTask: Task<Void, Never>?

    init(source: TryOnSource,
         client: TryOnClientProtocol = TryOnClient(),
         faceDataOverride: Data? = nil) {
        self.source = source
        self.client = client
        self.faceDataOverride = faceDataOverride
    }

    /// 画面表示時に呼ぶ。同じ顔 × 同じコーデはキャッシュ即表示 (生成コスト0)。
    func start() {
        guard case .idle = phase else { return }
        if let faceHash = FaceImageStore.shared.faceHash,
           let cached = TryOnCache.shared.image(for: source.cacheKey(faceHash: faceHash)) {
            phase = .success(cached, fromCache: true)
            return
        }
        generate(quality: .standard)
    }

    /// キャッシュを無視して上位モデルで作り直す (結果が気に入らないとき用)。
    /// 初回 standard → 再生成 high の二段構えでコスパと満足度を両立する。
    func regenerate() {
        didSaveToPhotos = false
        generate(quality: .high)
    }

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
    }

    func saveToPhotos() {
        guard case .success(let image, _) = phase else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        didSaveToPhotos = true
        Haptic.notify(.success)
        ToastManager.shared.show("写真に保存しました", style: .normal)
    }

    private func generate(quality: TryOnQuality) {
        generationTask?.cancel()
        guard let faceData = faceDataOverride ?? FaceImageStore.shared.sendData() else {
            phase = .failure(TryOnFailure(
                code: "NO_FACE",
                message: "顔写真が見つかりません。もう一度登録してください。",
                allowsRetry: false,
                suggestsFaceChange: true))
            return
        }
        phase = .loading
        let userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue))

        generationTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.client.generate(
                userId: userId, faceImage: faceData, gender: gender,
                source: self.source, quality: quality)
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let response):
                guard let data = response.imageData, let image = UIImage(data: data) else {
                    self.phase = .failure(Self.failure(for: .decode))
                    return
                }
                if let faceHash = FaceImageStore.shared.faceHash {
                    TryOnCache.shared.store(data, for: self.source.cacheKey(faceHash: faceHash))
                }
                Haptic.notify(.success)
                self.phase = .success(image, fromCache: false)
            case .failure(let error):
                if error.code == "CANCELLED" { return }
                self.phase = .failure(Self.failure(for: error))
            }
        }
    }

    /// サーバの構造化エラー code → ユーザー文言と挙動 (docs: irodori-api の _tryon_http)
    static func failure(for error: TryOnAPIError) -> TryOnFailure {
        switch error.code {
        case "DISABLED":
            return TryOnFailure(code: error.code,
                                message: "試着機能は現在メンテナンス中です。しばらくしてからお試しください。",
                                allowsRetry: false, suggestsFaceChange: false)
        case "LIMIT_EXCEEDED":
            return TryOnFailure(code: error.code,
                                message: "本日の試着回数の上限に達しました。また明日お試しください。",
                                allowsRetry: false, suggestsFaceChange: false)
        case "RATE_LIMIT":
            return TryOnFailure(code: error.code,
                                message: "混み合っています。少し時間をおいてお試しください。",
                                allowsRetry: true, suggestsFaceChange: false)
        case "SAFETY":
            return TryOnFailure(code: error.code,
                                message: "この写真では生成できませんでした。顔がはっきり写った別の写真をお試しください。",
                                allowsRetry: false, suggestsFaceChange: true)
        case "FETCH_FAILED":
            return TryOnFailure(code: error.code,
                                message: "コーデ画像の取得に失敗しました。もう一度お試しください。",
                                allowsRetry: true, suggestsFaceChange: false)
        case "BAD_REQUEST":
            return TryOnFailure(code: error.code,
                                message: "試着に必要なアイテム情報が不足しています。",
                                allowsRetry: false, suggestsFaceChange: false)
        case "TIMEOUT":
            return TryOnFailure(code: error.code,
                                message: "時間がかかりすぎたため中断しました。もう一度お試しください。",
                                allowsRetry: true, suggestsFaceChange: false)
        case "NETWORK":
            return TryOnFailure(code: error.code,
                                message: "通信に失敗しました。電波の良い場所でお試しください。",
                                allowsRetry: true, suggestsFaceChange: false)
        default:
            return TryOnFailure(code: error.code,
                                message: "生成に失敗しました。時間をおいてお試しください。",
                                allowsRetry: true, suggestsFaceChange: false)
        }
    }
}
