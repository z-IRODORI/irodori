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
    var selectedGender: Gender = .male
    var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let userDefaults = UserDefaults.standard

    func okButtonTapped() async {
        let createUserClient: CreateUserClient = CreateUserClient()
        let uid = UUID().uuidString
        userDefaults.set(uid, forKey: UserDefaultsKey.userId.rawValue)

        let user = User(username: username, birthday: BirthDay(year: "0", month: "0", day: "0"), gender: selectedGender)
        // API の成否に関わらずローカルに先行保存する
        if let encoded = try? JSONEncoder().encode(user) {
            userDefaults.set(encoded, forKey: UserDefaultsKey.userInfo.rawValue)
            userDefaults.set(selectedGender.apiValue, forKey: UserDefaultsKey.gender.rawValue)
            userDefaults.set(true, forKey: UserDefaultsKey.hasCompletedUserInfo.rawValue)
        }
        do {
            let _ = try await createUserClient.post(createUserRequest: .init(id: uid, cognito_id: uid, user_name: username, year: 0, month: 0, day: 0, gender: selectedGender.number))
        } catch {}
    }
}
