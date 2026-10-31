//
//  ForceUpdate.swift
//  irodori
//
//  強制アップデート。起動時とアプリに戻ったときに GET /api/app/version で最低バージョンを確かめ、
//  今のアプリが古ければ、閉じられないアップデート画面を出して先に進ませない。
//  - 最低バージョンはサーバ (Firestore app_config/ios) で決める。デプロイ不要で切り替えられる
//  - 一度知った最低バージョンは端末に覚えておき、通信できないときもアップデート画面を出す
//  - 確かめられない (初回で通信できない) ときは止めない
//

import SwiftUI

struct AppVersionConfig: Decodable {
    let min_version: String
    let message: String
    let store_url: String
}

enum AppVersion {
    /// "3.10.1" → [3, 10, 1]。数字でない部分は 0
    static func parse(_ v: String) -> [Int] {
        var parts = v.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        while parts.count < 3 { parts.append(0) }
        return Array(parts.prefix(3))
    }

    static func isOlder(_ current: String, than minimum: String) -> Bool {
        parse(current).lexicographicallyPrecedes(parse(minimum))
    }

    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}

@MainActor
@Observable
final class ForceUpdateChecker {
    static let shared = ForceUpdateChecker()

    private static let minKey = "forceUpdate.minVersion"
    private static let messageKey = "forceUpdate.message"
    private static let urlKey = "forceUpdate.storeURL"

    /// アップデートが必要か (true の間はアップデート画面だけを出す)
    private(set) var required: Bool
    private(set) var message: String
    private(set) var storeURL: URL

    private init() {
        let d = UserDefaults.standard
        let known = d.string(forKey: Self.minKey) ?? "0.0.0"
        required = AppVersion.isOlder(AppVersion.current, than: known)
        message = d.string(forKey: Self.messageKey) ?? "新しいバージョンのIRODORIが出ています。App Storeからアップデートしてね。"
        storeURL = URL(string: d.string(forKey: Self.urlKey) ?? "") ?? URL(string: "https://apps.apple.com/jp/app/id6744557697")!
    }

    func check() async {
        var components = URLComponents(string: "\(PartnerProfileClient.defaultBaseURL)/api/app/version")
        components?.queryItems = [URLQueryItem(name: "platform", value: "ios"),
                                  URLQueryItem(name: "current", value: AppVersion.current)]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode < 400,
              let config = try? JSONDecoder().decode(AppVersionConfig.self, from: data) else { return }
        let d = UserDefaults.standard
        d.set(config.min_version, forKey: Self.minKey)
        d.set(config.message, forKey: Self.messageKey)
        d.set(config.store_url, forKey: Self.urlKey)
        message = config.message
        if let u = URL(string: config.store_url) { storeURL = u }
        required = AppVersion.isOlder(AppVersion.current, than: config.min_version)
    }
}

/// 閉じられないアップデート画面
struct ForceUpdateView: View {
    let message: String
    let storeURL: URL
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            EntryBackground()
            VStack(spacing: 16) {
                Spacer()
                VStack(spacing: 8) {
                    Text("アップデートのお願い")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RenewalTokens.ink)
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(RenewalTokens.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("いまのバージョン: \(AppVersion.current)")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(RenewalTokens.muted)
                }
                Button {
                    Haptic.impact(.medium)
                    openURL(storeURL)
                } label: {
                    Text("App Storeでアップデート")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RenewalTokens.primaryFill)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .interactiveDismissDisabled()
    }
}
