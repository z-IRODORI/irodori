//
//  User.swift
//  irodori
//
//  Created by Claude on 2025/07/07.
//

import Foundation

enum Gender: String, CaseIterable, Codable {
    case male = "男性"
    case female = "女性"
    case other = "その他"
}

struct User: Codable {
    let username: String
    let birthday: Date
    let gender: Gender
    
    init(username: String, birthday: Date, gender: Gender) {
        self.username = username
        self.birthday = birthday
        self.gender = gender
    }
}