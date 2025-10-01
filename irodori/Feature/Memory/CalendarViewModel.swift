//
//  CalendarViewModel.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    var months: [Month] = []
    let daysOfTheWeek: [Week] = Week.allCases
    var coordinateListResponses: [[CoordinateListResponse]] = []
    let uid: String
    var coordinateDetail: CoordinateDetailResponse?
    var isLoadingDetail = false

    let apiClient: CoordinateListClientProtocol
    let coordinateDetailClient: CoordinateDetailClientProtocol
    init(apiClient: CoordinateListClientProtocol, coordinateDetailClient: CoordinateDetailClientProtocol = CoordinateDetailClient(), repository: SignUpDateRepositoryProtocol = SignUpDateRepository()) {
        self.apiClient = apiClient
        self.coordinateDetailClient = coordinateDetailClient
        self.uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue)!
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()

        // 年月を一意にするために最初の日に合わせる
        guard let signupDate = repository.load(),
              let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: signupDate)),
              let endDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today))
        else {
            // TODO: エラー表示
            self.months = []
            return
        }

        var date = startDate
        var monthList: [Month] = []

        while date <= endDate {
            let components = calendar.dateComponents([.year, .month], from: date)
            if let year = components.year, let month = components.month {
                let title = "\(month)月"
                monthList.append(Month(title: title, monthOfTheYear: month, year: year))
            }

            // 次の月へ進める
            date = calendar.date(byAdding: .month, value: 1, to: date)!
        }
        self.months = monthList
    }

    func onAppear() async {
        do {
            for month in months {
                let result = try await apiClient.get(uid: uid, year: month.year, month: month.monthOfTheYear)
                switch result {
                case .success(let response):
                    coordinateListResponses.append(response)
                case .failure(let error):
                    print(error)
                }
            }
        } catch {

        }
    }
    
    func fetchCoordinateDetail(targetDate: String) async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        
        do {
            let result = try await coordinateDetailClient.get(uid: uid, targetDate: targetDate)
            switch result {
            case .success(let response):
                if let firstDetail = response.first {
                    coordinateDetail = firstDetail
                }
            case .failure(let error):
                print("Failed to fetch coordinate detail: \(error)")
            }
        } catch {
            print("Error fetching coordinate detail: \(error)")
        }
    }
}

