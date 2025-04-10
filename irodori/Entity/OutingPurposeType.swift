//
//  OutingPurposeType.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/09.
//

import Foundation

enum OutingPurposeType: CaseIterable {
    case business
    case couple
    case shopping
    case school
    case dining
    case diningWithOppositeSex
    case excercise
    case cafe
    case nothing

    var name: String {
        switch self {
        case .business: return "職場"
        case .couple: return "デート"
        case .shopping: return "買い物"
        case .school: return "大学"
        case .cafe: return "カフェ"
        case .dining: return "飲み会（同性のみ）"
        case .diningWithOppositeSex: return "飲み会"
        case .excercise: return "運動"
        case .nothing: return "特になし"
        }
    }

    var number: Int {
        switch self {
        case .business: return 0
        case .couple: return 1
        case .shopping: return 2
        case .school: return 3
        case .cafe: return 4
        case .dining: return 5
        case .diningWithOppositeSex: return 6
        case .excercise: return 7
        case .nothing: return 8
        }
    }
}
