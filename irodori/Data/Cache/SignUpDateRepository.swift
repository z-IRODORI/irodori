//
//  SignUpDateRepository.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/07/10.
//

import Foundation

protocol SignUpDateRepositoryProtocol {
    func saveNow()
    func load() -> Date?
}

final class SignUpDateRepository: SignUpDateRepositoryProtocol {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// 現在の日本時間を保存（UTCベースのDateとして保存）
    func saveNow() {
        let now = Date()
        userDefaults.set(now, forKey: UserDefaultsKey.signUpDate.rawValue)
    }

    /// 保存されたDateを取得（UTCとして保存されていたDate）
    func load() -> Date? {
        return userDefaults.object(forKey: UserDefaultsKey.signUpDate.rawValue) as? Date
    }
}
