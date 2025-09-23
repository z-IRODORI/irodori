//
//  FetchState.swift
//  irodori
//
//  Created by yuki.hamada on 2025/09/23.
//

import Foundation

enum FetchState<Response> {
    case initial
    case loading
    case loaded(Response)
    case failed(Error)
}
