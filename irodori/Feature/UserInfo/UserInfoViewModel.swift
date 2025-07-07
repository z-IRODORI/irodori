//
//  UserInfoViewModel.swift
//  irodori
//
//  Created by Claude on 2025/07/07.
//

import SwiftUI

@Observable
final class UserInfoViewModel {
    var username: String = ""
    var birthday: Date = Date()
    var selectedYear: Int = Calendar.current.component(.year, from: Date()) - 20
    var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    var selectedDay: Int = Calendar.current.component(.day, from: Date())
    var selectedGender: Gender = .male
    var hasCompletedUserInfo: Bool = false
    
    // 数値入力用プロパティ
    var yearInput: String = ""
    var monthInput: String = ""
    var dayInput: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let userInfoKey = "userInfo"
    private let userInfoCompletedKey = "hasCompletedUserInfo"
    
    init() {
        checkUserInfoCompletion()
        setupInitialValues()
    }
    
    private func setupInitialValues() {
        yearInput = String(selectedYear)
        monthInput = String(format: "%02d", selectedMonth)
        dayInput = String(format: "%02d", selectedDay)
    }
    
    private func checkUserInfoCompletion() {
        hasCompletedUserInfo = userDefaults.bool(forKey: userInfoCompletedKey)
        
        if hasCompletedUserInfo {
            loadUserInfo()
        }
    }
    
    private func loadUserInfo() {
        guard let data = userDefaults.data(forKey: userInfoKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        
        username = user.username
        birthday = user.birthday
        selectedYear = Calendar.current.component(.year, from: user.birthday)
        selectedMonth = Calendar.current.component(.month, from: user.birthday)
        selectedDay = Calendar.current.component(.day, from: user.birthday)
        selectedGender = user.gender
        
        // 数値入力フィールドも更新
        yearInput = String(selectedYear)
        monthInput = String(format: "%02d", selectedMonth)
        dayInput = String(format: "%02d", selectedDay)
    }
    
    func saveUserInfo() {
        updateBirthdayFromInputs()
        let user = User(username: username, birthday: birthday, gender: selectedGender)
        
        if let encoded = try? JSONEncoder().encode(user) {
            userDefaults.set(encoded, forKey: userInfoKey)
            userDefaults.set(true, forKey: userInfoCompletedKey)
            hasCompletedUserInfo = true
        }
    }
    
    private func updateBirthdayFromInputs() {
        guard let year = Int(yearInput),
              let month = Int(monthInput),
              let day = Int(dayInput) else {
            return
        }
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        if let date = Calendar.current.date(from: components) {
            birthday = date
            selectedYear = year
            selectedMonth = month
            selectedDay = day
        }
    }
    
    // 数値入力処理メソッド
    func updateYearInput(_ input: String) {
        let filtered = input.filter { $0.isNumber }
        if filtered.count <= 4 {
            yearInput = filtered
            if filtered.count == 4 {
                // 年の入力が完了したら月フィールドにフォーカスを移すための通知
                if let year = Int(filtered), year >= 1900 && year <= 2100 {
                    selectedYear = year
                }
            }
        }
    }
    
    func updateMonthInput(_ input: String) {
        let filtered = input.filter { $0.isNumber }
        if filtered.count <= 2 {
            monthInput = filtered
            if filtered.count == 2 {
                if let month = Int(filtered), month >= 1 && month <= 12 {
                    selectedMonth = month
                }
            } else if filtered.count == 1 {
                if let month = Int(filtered), month >= 1 && month <= 9 {
                    monthInput = String(format: "%02d", month)
                    selectedMonth = month
                }
            }
        }
    }
    
    func updateDayInput(_ input: String) {
        let filtered = input.filter { $0.isNumber }
        if filtered.count <= 2 {
            dayInput = filtered
            if filtered.count == 2 {
                if let day = Int(filtered), day >= 1 && day <= 31 {
                    selectedDay = day
                }
            } else if filtered.count == 1 {
                if let day = Int(filtered), day >= 1 && day <= 9 {
                    dayInput = String(format: "%02d", day)
                    selectedDay = day
                }
            }
        }
    }
    
    var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isBirthdayValid
    }
    
    var isBirthdayValid: Bool {
        guard let year = Int(yearInput), year >= 1900 && year <= 2100,
              let month = Int(monthInput), month >= 1 && month <= 12,
              let day = Int(dayInput), day >= 1 && day <= 31 else {
            return false
        }
        
        // 実際の日付として有効かチェック
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        return Calendar.current.date(from: components) != nil
    }
    
    var formattedBirthday: String {
        return "\(yearInput)年\(monthInput)月\(dayInput)日"
    }
}