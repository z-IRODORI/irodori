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
    case outfitPlanner
    case tomorrowPlanner
    case generalChat(conversationId: String?)
    case chatHistoryList
    case chatHistoryDetail(conversationId: String)
    case coordinateReview(CoordinateReviewParams)
    case coordinateDetail(CoordinateDetailParams)
    case profileEdit
    case favorites
    case fashionType
    case fashionTypeResult(FashionTypeResponse)
    case recommendCoordinateByStandardItem(RecommendCoordinateParams)
    case coordinateCollage
    case outfitSuggestion
    case addItemBySearch

    struct CoordinateReviewParams: Hashable {
        let image: UIImage?
        let fromFirstTakePhotoView: Bool
    }

    struct CoordinateDetailParams: Hashable {
        let coordinateId: String
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
