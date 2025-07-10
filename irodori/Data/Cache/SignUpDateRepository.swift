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
    private let userDefaults: UserDefaults = UserDefaults.standard

    /// 現在の日本時間を保存（UTCベースのDateとして保存）
    func saveNow() {
        let now = Date()
        userDefaults.set(now, forKey: UserDefaultsKey.signUpDate.rawValue)
    }

    /// 保存されたDateを取得（UTCとして保存されていたDate）
    func load() -> Date? {
        return userDefaults.object(forKey: UserDefaultsKey.signUpDate.rawValue) as? Date
    }

    /// Date → 日本時間の String（例: "2025-07-10 20:30:00"）
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }

    /// String → Date（日本時間で解釈）
    static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.date(from: string)
    }
}
