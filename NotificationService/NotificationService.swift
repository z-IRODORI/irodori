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

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        bestAttempt = content

        guard let url = Self.imageURL(in: request.content.userInfo) else {
            contentHandler(content)
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { [weak self] location, response, _ in
            guard let self, let content = self.bestAttempt else { return }
            defer { contentHandler(content) }
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
        if let contentHandler, let bestAttempt {
            contentHandler(bestAttempt)
        }
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
