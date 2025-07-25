//
//  InputUserInfoViewModel.swift
//  irodori
//
//  Created by Claude on 2025/07/07.
//

import SwiftUI



@Observable
@MainActor
final class InputUserInfoViewModel {
    var username: String = ""
    var birthDay: BirthDay = .init(year: "", month: "", day: "")
    var selectedGender: Gender = .male
    /// 実際の日付として有効かチェック
    var isBirthdayValid: Bool {
        guard let year = Int(birthDay.year), year >= 1900 && year <= 2100,
              let month = Int(birthDay.month), month >= 1 && month <= 12,
              let day = Int(birthDay.day), day >= 1 && day <= 31 else {
            return false
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) != nil
    }
    var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isBirthdayValid
    }

    private let userDefaults = UserDefaults.standard

    func updateYear(_ year: String) {
        birthDay.year = year
    }
    func updateMonth(_ month: String) {
        birthDay.month = month
    }
    func updateDay(_ day: String) {
        birthDay.day = day
    }

    func okButtonTapped() async {
        let createUserClient: CreateUserClient = CreateUserClient()
        let uid = UUID().uuidString
        userDefaults.set(uid, forKey: UserDefaultsKey.userId.rawValue)

        let user = User(username: username, birthday: birthDay, gender: selectedGender)
        do {
            let _ = try await createUserClient.post(createUserRequest: .init(id: uid, cognito_id: uid, user_name: username, year: Int(birthDay.year)!, month: Int(birthDay.month)!, day: Int(birthDay.day)!, gender: selectedGender.number))
            if let encoded = try? JSONEncoder().encode(user) {
                userDefaults.set(encoded, forKey: UserDefaultsKey.userInfo.rawValue)
                userDefaults.set(true, forKey: UserDefaultsKey.hasCompletedUserInfo.rawValue)
            }
        } catch {

        }
    }
}
