//
//  AuthManager.swift
//  irodori
//

import Foundation
import FirebaseAuth
import CryptoKit
import AuthenticationServices

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

    /// Sign in with Apple（Firebase連携）
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: fullName
        )
        let result = try await Auth.auth().signIn(with: credential)
        self.isAuthenticated = true
        self.currentUserID = result.user.uid

        // Appleは初回のみ氏名を返すため、displayNameが未設定なら更新
        if let fullName, let givenName = fullName.givenName, result.user.displayName == nil {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = [fullName.familyName, givenName].compactMap { $0 }.joined(separator: " ")
            try? await changeRequest.commitChanges()
        }

        self.authError = nil
    }

    /// Apple Sign Inで認証済みかどうか
    var isSignedInWithApple: Bool {
        Auth.auth().currentUser?.providerData.contains(where: { $0.providerID == "apple.com" }) ?? false
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

    // MARK: - Nonce helpers（Apple Sign In用）

    static func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let hashedData = SHA256.hash(data: Data(input.utf8))
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
