//
//  ViewType.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/15.
//

import UIKit

enum ViewType: Hashable {
    case camera
    case calendar
    case coordinateReview(UIImage?)
    case coordinateDetail(CoordinateDetailParams)

    struct CoordinateDetailParams: Hashable {
        let uid: String
        let targetDateString: String
        let coordinateImageURL: String
    }
}
