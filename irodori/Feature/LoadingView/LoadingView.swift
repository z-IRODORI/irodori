//
//  LoadingView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/03.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 48) {
            Text("レビューコメント生成中...")
                .font(.system(size: 20, weight: .bold))
            Image("")
                .resizable()
        }
    }
}

#Preview {
    LoadingView()
}
