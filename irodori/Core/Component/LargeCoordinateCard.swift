//
//  LargeCoordinateCardView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/03.
//

import SwiftUI

struct LargeCoordinateCard: View {
    let coordinateImage: UIImage
    let currentSchedule: String
    let aiCatchphrase: String


    var body: some View {
        ZStack {
            Image(uiImage: coordinateImage)
                .resizable()
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geometry.size.height / 2)
                        .position(x: geometry.size.width / 2,
                                  y: geometry.size.height - (geometry.size.height / 4))
                    }
                }
                .overlay {
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.3), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(maxWidth: .infinity, maxHeight: 50)
                        .position(x: geometry.size.width / 2, y: 24)
                    }
                }

            Text("\(currentSchedule)")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
            Text("\(aiCatchphrase)")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
}

#Preview {
    LargeCoordinateCard(coordinateImage: .init(resource: .coordinate5), currentSchedule: "2000/01/01", aiCatchphrase: "aiCatchphrase")
}
