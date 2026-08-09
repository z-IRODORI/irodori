//
//  PhoneAuthViewModel.swift
//  irodori
//
//  電話番号 (SMS認証) による会員登録/ログインの状態管理。
//

import Foundation
import FirebaseAuth

@MainActor
@Observable
final class PhoneAuthViewModel {
    enum Step {
        case phoneNumber
        case verificationCode
    }

    private(set) var step: Step = .phoneNumber
    var phoneNumberText: String = ""   // ハイフン付き表示 (例: 090-1234-5678)
    var codeText: String = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var resendRemainingSeconds = 0

    private var verificationID: String?
    private var countdownTask: Task<Void, Never>?

    static let codeLength = 6
    private static let resendCooldownSeconds = 60

    /// 入力中の電話番号 (数字のみ)
    private var phoneDigits: String {
        phoneNumberText.filter { $0.isNumber }
    }

    /// 日本の携帯電話番号として妥当か (060/070/080/090 + 8桁)
    var isPhoneNumberValid: Bool {
        let digits = phoneDigits
        guard digits.count == 11 else { return false }
        return ["060", "070", "080", "090"].contains(String(digits.prefix(3)))
    }

    /// E.164 形式 (例: "+819012345678")
    private var e164PhoneNumber: String {
        "+81" + phoneDigits.dropFirst()
    }

    var canResend: Bool {
        resendRemainingSeconds == 0 && !isLoading
    }

    /// 電話番号入力を数字のみ・11桁までに整形し、3-4-4 でハイフンを入れる。
    /// "+81 90-1234-5678" のような国際形式のペーストは 0 始まりの国内形式に正規化する。
    func formatPhoneNumberText(_ newValue: String) {
        var allDigits = newValue.filter { $0.isNumber }
        // 11桁に切り詰める前に判定しないと "8190..." 12桁の 81 プレフィックスを見失う
        if allDigits.hasPrefix("81"), allDigits.count >= 12 {
            // "+81 090-..." のようにトランクの 0 を残した表記は 0 を重ねない
            let rest = allDigits.dropFirst(2)
            allDigits = rest.hasPrefix("0") ? String(rest) : "0" + rest
        }
        let digits = String(allDigits.prefix(11))
        var formatted = String(digits.prefix(3))
        if digits.count > 3 {
            formatted += "-" + digits.dropFirst(3).prefix(4)
        }
        if digits.count > 7 {
            formatted += "-" + digits.dropFirst(7)
        }
        phoneNumberText = formatted
    }

    /// 認証コード入力を数字のみ・6桁までに整形する
    func formatCodeText(_ newValue: String) {
        codeText = String(newValue.filter { $0.isNumber }.prefix(Self.codeLength))
    }

    /// SMS 認証コードを送信して認証コード入力ステップへ進む
    func sendCode() async {
        guard isPhoneNumberValid, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            verificationID = try await AuthManager.shared.sendVerificationCode(toPhoneNumber: e164PhoneNumber)
            codeText = ""
            step = .verificationCode
            startResendCooldown()
        } catch {
            Self.logError(error, context: "send_code")
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    /// 認証コードを再送信する
    func resendCode() async {
        guard canResend else { return }
        isLoading = true
        errorMessage = nil
        do {
            verificationID = try await AuthManager.shared.sendVerificationCode(toPhoneNumber: e164PhoneNumber)
            codeText = ""
            startResendCooldown()
        } catch {
            Self.logError(error, context: "resend_code")
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    /// 6桁コードでサインインする (初回=会員登録 / 2回目以降=ログイン)。成功時 true。
    func verifyCode() async -> Bool {
        guard let verificationID, codeText.count == Self.codeLength, !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        do {
            try await AuthManager.shared.signIn(verificationID: verificationID, code: codeText)
            isLoading = false
            countdownTask?.cancel()
            return true
        } catch {
            Self.logError(error, context: "verify_code")
            errorMessage = Self.message(for: error)
            codeText = ""
            isLoading = false
            return false
        }
    }

    /// 電話番号の入力し直しに戻る
    func backToPhoneNumberStep() {
        countdownTask?.cancel()
        resendRemainingSeconds = 0
        codeText = ""
        errorMessage = nil
        step = .phoneNumber
    }

    private func startResendCooldown() {
        countdownTask?.cancel()
        resendRemainingSeconds = Self.resendCooldownSeconds
        countdownTask = Task { [weak self] in
            while let self, self.resendRemainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.resendRemainingSeconds -= 1
            }
        }
    }

    /// 原因特定用: 実エラーコードを Analytics とコンソールに記録する
    private static func logError(_ error: Error, context: String) {
        let nsError = error as NSError
        let errorName = nsError.userInfo["FIRAuthErrorUserInfoNameKey"] as? String ?? "unknown"
        print("🔴 [PhoneAuth] \(context) failed: domain=\(nsError.domain) code=\(nsError.code) name=\(errorName) desc=\(nsError.localizedDescription)")
        AnalyticsLogger.shared.log(error: .phoneAuthError, parameters: [
            "context": context,
            "error_domain": nsError.domain,
            "error_code": nsError.code,
            "error_name": errorName,
        ])
    }

    private static func message(for error: Error) -> String {
        let nsError = error as NSError
        let message: String
        switch AuthErrorCode(rawValue: nsError.code) {
        case .invalidPhoneNumber, .missingPhoneNumber:
            message = "電話番号の形式が正しくありません。もう一度ご確認ください。"
        case .invalidVerificationCode:
            message = "認証コードが正しくありません。もう一度入力してください。"
        case .sessionExpired:
            message = "認証コードの有効期限が切れました。再送信してください。"
        case .tooManyRequests, .quotaExceeded:
            message = "リクエストが多すぎます。しばらく時間をおいてお試しください。"
        case .networkError:
            message = "通信エラーが発生しました。電波の良い場所でお試しください。"
        case .captchaCheckFailed:
            message = "認証に失敗しました。もう一度お試しください。"
        default:
            message = "エラーが発生しました。もう一度お試しください。"
        }
        #if DEBUG
        return message + "（コード: \(nsError.code)）"
        #else
        return message
        #endif
    }
}
