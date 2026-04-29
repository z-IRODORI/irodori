//
//  ToastManager.swift
//  irodori
//

import Foundation

@MainActor
@Observable
final class ToastManager {
    static let shared = ToastManager()

    var message: String? = nil
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String) {
        self.message = message
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { self.message = nil }
        }
    }
}
