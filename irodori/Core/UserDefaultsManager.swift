//
//  UserDefaultsManager.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

protocol UserDefaultsManagerProtocol {
    func save<T: Codable>(_ value: T, forKey key: UserDefaultsKey)
    func load<T: Codable>(_ type: T.Type, forKey key: UserDefaultsKey) -> T?
    func remove(forKey key: UserDefaultsKey)
    func exists(forKey key: UserDefaultsKey) -> Bool
}

final class UserDefaultsManager: UserDefaultsManagerProtocol {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func save<T: Codable>(_ value: T, forKey key: UserDefaultsKey) {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: key.rawValue)
        } catch {
            print("Failed to save data for key \(key.rawValue): \(error)")
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: UserDefaultsKey) -> T? {
        guard let data = userDefaults.data(forKey: key.rawValue) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to load data for key \(key.rawValue): \(error)")
            return nil
        }
    }
    
    func remove(forKey key: UserDefaultsKey) {
        userDefaults.removeObject(forKey: key.rawValue)
    }
    
    func exists(forKey key: UserDefaultsKey) -> Bool {
        return userDefaults.object(forKey: key.rawValue) != nil
    }
}