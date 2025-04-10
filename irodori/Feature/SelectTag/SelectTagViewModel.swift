//
//  SelectTagViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/09.
//

import Foundation

@Observable
@MainActor
final class SelectTagViewModel {
    let tags: [OutingPurposeType] = OutingPurposeType.allCases
    var selectedTag: OutingPurposeType = .couple

    func tappedTagButton(tag: OutingPurposeType) {
        selectedTag = tag
    }
}
