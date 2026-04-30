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
    case tomorrowPlanner
    case coordinateReview(CoordinateReviewParams)
    case coordinateDetail(CoordinateDetailParams)
    case profileEdit
    case fashionType
    case fashionTypeResult(FashionTypeResponse)
    case recommendCoordinateByStandardItem(RecommendCoordinateParams)

    struct CoordinateReviewParams: Hashable {
        let image: UIImage?
        let fromFirstTakePhotoView: Bool
    }

    struct CoordinateDetailParams: Hashable {
        let uid: String
        let targetDateString: String
        let coordinateImageURL: String
        let showHeader: Bool
    }

    struct RecommendCoordinateParams: Hashable {
        let results: [CoordinateRecommendResult]
        let selectedItems: [StandardItem]

        static func == (lhs: RecommendCoordinateParams, rhs: RecommendCoordinateParams) -> Bool {
            lhs.results.map { $0.item_id } == rhs.results.map { $0.item_id } &&
            lhs.selectedItems.map { $0.id } == rhs.selectedItems.map { $0.id }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(results.map { $0.item_id })
            hasher.combine(selectedItems.map { $0.id })
        }
    }
}
