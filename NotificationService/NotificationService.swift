//
//  NotificationService.swift
//  NotificationService (Notification Service Extension)
//
//  プッシュ通知に画像を添付する。サーバ (FCM) は APNs の fcm_options.image と
//  data.image_url に撮影画像の URL を入れて送るので、ここでダウンロードして
//  UNNotificationAttachment にする。失敗しても通知本体はそのまま出す。
//

import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?
    /// 完了 (contentHandler) は必ず1回だけ呼ぶ。ダウンロードの完了と時間切れが重なっても二重に呼ばない
    private let lock = NSLock()

    private func deliver(_ content: UNNotificationContent) {
        lock.lock()
        let handler = contentHandler
        contentHandler = nil
        lock.unlock()
        handler?(content)
    }

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        bestAttempt = content

        guard let url = Self.imageURL(in: request.content.userInfo) else {
            deliver(content)
            return
        }

        // self を強く持つ (弱参照だと self が先に消えたとき、通知が出ないまま終わる)
        let task = URLSession.shared.downloadTask(with: url) { location, response, _ in
            defer { self.deliver(content) }
            guard let location else { return }
            let ext = Self.fileExtension(url: url, response: response)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            do {
                try FileManager.default.moveItem(at: location, to: dest)
                let attachment = try UNNotificationAttachment(identifier: "capture", url: dest, options: nil)
                content.attachments = [attachment]
            } catch {
                // 添付に失敗しても本文は出す
            }
        }
        task.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let bestAttempt { deliver(bestAttempt) }
    }

    // MARK: - 画像 URL の取り出し

    static func imageURL(in userInfo: [AnyHashable: Any]) -> URL? {
        // FCM が APNs 向けに付ける fcm_options.image を優先し、無ければ data.image_url
        if let fcm = userInfo["fcm_options"] as? [AnyHashable: Any],
           let s = fcm["image"] as? String, let url = URL(string: s) {
            return url
        }
        if let s = userInfo["image_url"] as? String, !s.isEmpty, let url = URL(string: s) {
            return url
        }
        return nil
    }

    static func fileExtension(url: URL, response: URLResponse?) -> String {
        if let mime = response?.mimeType {
            if mime.contains("png") { return "png" }
            if mime.contains("jpeg") || mime.contains("jpg") { return "jpg" }
        }
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif"].contains(ext) ? ext : "jpg"
    }
}
