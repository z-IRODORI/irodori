//
//  ToastManager.swift
//  irodori
//

import Foundation

/// トーストの見た目。エラー = 赤背景、正常 (成功/案内) = 黒背景
enum ToastStyle {
    case error
    case normal
}

@MainActor
@Observable
final class ToastManager {
    static let shared = ToastManager()

    var message: String? = nil
    var style: ToastStyle = .error
    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// 既存呼び出しの大半が失敗通知のため、デフォルトは .error (赤)。
    /// 成功・案内は style: .normal (黒) を明示する。
    func show(_ message: String, style: ToastStyle = .error) {
        self.message = message
        self.style = style
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { self.message = nil }
        }
    }
}
