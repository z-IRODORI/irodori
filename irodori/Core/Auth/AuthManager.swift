//
//  AuthManager.swift
//  irodori
//
//  会員登録/ログインは「電話番号 (SMS認証)」のみ (Firebase Phone Auth)。
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
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = (user != nil)
                self?.currentUserID = user?.uid
            }
        }
    }

    /// 電話番号 (E.164 形式, 例: "+819012345678") に SMS 認証コードを送る。
    /// 成功すると、後続の signIn で使う verificationID を返す。
    func sendVerificationCode(toPhoneNumber e164PhoneNumber: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider().verifyPhoneNumber(e164PhoneNumber, uiDelegate: nil) { verificationID, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: verificationID ?? "")
            }
        }
    }

    /// verificationID と受信した 6 桁コードでサインインする (初回=会員登録 / 2回目以降=ログイン)。
    func signIn(verificationID: String, code: String) async throws {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        let result = try await Auth.auth().signIn(with: credential)
        self.isAuthenticated = true
        self.currentUserID = result.user.uid
        self.authError = nil
    }

    /// サインイン済みか (電話番号認証)
    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
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

    /// 現在のユーザー
    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
}
