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
    case coordinateReview(CoordinateReviewParams)
    case coordinateDetail(CoordinateDetailParams)
    case profileEdit

    struct CoordinateReviewParams: Hashable {
        let image: UIImage?
        let fromFirstTakePhotoView: Bool
    }

    struct CoordinateDetailParams: Hashable {
        let uid: String
        let targetDateString: String
        let coordinateImageURL: String
    }
}
