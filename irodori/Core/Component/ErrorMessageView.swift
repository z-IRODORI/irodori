//
//  ErrorMessageView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/28.
//

import SwiftUI

struct ErrorMessageView: View {
    let errorMessage: ErrorMessage
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("\(errorMessage.title)")
                    .font(.system(size: 16, weight: .bold))

                Text("\(errorMessage.description)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.gray)

                Button(action: {
                    dismiss()
                }, label: {
                    Text("OK")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 120, maxHeight: 30)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 48))
                })
                .padding(.top, 12)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 32)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ErrorMessageView(
        errorMessage: .init(title: HTTPError.unknownError.title, description: HTTPError.unknownError.errorDescription),
        dismiss: {}
    )
}
