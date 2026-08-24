//
//  FaceImageStore.swift
//  irodori
//
//  試着に使う顔写真の端末内ストア。
//
//  プライバシー方針: 顔写真は Documents 配下 (face_image.jpg / face_thumb.jpg)
//  だけに永続化し、サーバへは試着生成のリクエスト時にのみ送信する。サーバ側は
//  保存しない (irodori-api/tryon_service.py 冒頭の方針とセット)。この前提を
//  変えるときは FaceRegistrationSheet の説明文も必ず更新すること。
//

import UIKit
import CryptoKit

final class FaceImageStore {
    static let shared = FaceImageStore()
    private init() {}

    private let imageFilename = "face_image.jpg"
    private let thumbFilename = "face_thumb.jpg"

    private var documents: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    private var imageFileURL: URL? { documents?.appendingPathComponent(imageFilename) }
    private var thumbFileURL: URL? { documents?.appendingPathComponent(thumbFilename) }

    var isRegistered: Bool {
        guard let url = imageFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// 送信用 (長辺 1024 / JPEG 0.85) とサムネ (顔クロップ・長辺 240) を保存する。
    /// 顔写真が変わると過去の試着結果は本人と一致しなくなるためキャッシュも消す。
    @discardableResult
    func save(original: UIImage, faceCrop: UIImage) -> Bool {
        guard let imageFileURL, let thumbFileURL else { return false }
        let send = original.fixedOrientation().resizedToFit(longEdge: 1024)
        guard let sendData = send.jpegData(compressionQuality: 0.85),
              let thumbData = faceCrop.fixedOrientation()
                  .resizedToFit(longEdge: 240)
                  .jpegData(compressionQuality: 0.8) else { return false }
        do {
            try sendData.write(to: imageFileURL, options: .atomic)
            try thumbData.write(to: thumbFileURL, options: .atomic)
        } catch {
            print("[FaceImageStore] save error: \(error)")
            return false
        }
        TryOnCache.shared.clear()
        return true
    }

    /// 試着リクエストに添付する JPEG データ
    func sendData() -> Data? {
        guard let imageFileURL else { return nil }
        return try? Data(contentsOf: imageFileURL)
    }

    func thumbnail() -> UIImage? {
        guard let thumbFileURL,
              let data = try? Data(contentsOf: thumbFileURL) else { return nil }
        return UIImage(data: data)
    }

    /// 結果キャッシュキーに混ぜる顔ファイルのハッシュ
    var faceHash: String? {
        guard let data = sendData() else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 退会・新規登録時のクリーンアップ (AccountLocalState から呼ばれる)。
    /// 残すと次のアカウントに前のユーザーの顔が写り込む。
    func deleteAll() {
        [imageFileURL, thumbFileURL].compactMap { $0 }.forEach {
            try? FileManager.default.removeItem(at: $0)
        }
        TryOnCache.shared.clear()
    }
}
