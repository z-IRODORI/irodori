//
//  AuthManager.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import Foundation
import FirebaseAuth

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    var isAuthenticated: Bool = false
    var currentUserID: String?
    var authError: Error?

    private init() {
        // 認証状態の監視
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = (user != nil)
                self?.currentUserID = user?.uid
            }
        }
    }

    /// 匿名認証を実行
    func signInAnonymously() async throws {
        do {
            let result = try await Auth.auth().signInAnonymously()
            self.isAuthenticated = true
            self.currentUserID = result.user.uid
            self.authError = nil
        } catch {
            self.authError = error
            throw error
        }
    }

    /// ログアウト
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.currentUserID = nil
            self.authError = nil
        } catch {
            self.authError = error
            throw error
        }
    }

    /// 現在のユーザーを取得
    var currentUser: FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
}
