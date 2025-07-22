//
//  SegmentationView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/07/22.
//

import SwiftUI
import CoreML

struct SegmentationView: View {
    let ViewModel: SegmentationViewModel = .init()

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 48) {
                ForEach(SegmentationViewModel.ImageType.allCases, id: \.self) { type in
                    Button(action: {
                        ViewModel.tappedImageChangeButton(type: type)
                    }) {
                        Text("\(type.rawValue)")
                    }
                }
            }

            Divider().frame(maxWidth: .infinity, maxHeight: 2)

            Button(action: {
                ViewModel.segment()
            }) {
                Text("コーデアイテム抽出")
                    .bold()
            }

            Text("\(String(format: "%.3f", ViewModel.segmentTime)) s")
                .padding(.bottom, -12)

            ZStack {
                Image(uiImage: ViewModel.inputUIImage)
                    .resizable()
                Image(uiImage: ViewModel.outputUIImage)
                    .resizable()
            }
            .aspectRatio(3/4, contentMode: .fit)

            HStack(spacing: 24) {
                Image(uiImage: ViewModel.topsUIImage)
                    .resizable()
                    .frame(maxWidth: 200, maxHeight: 200)
                Image(uiImage: ViewModel.bottomsUIImage)
                    .resizable()
                    .frame(maxWidth: 200, maxHeight: 200)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical,32)
    }
}

#Preview {
    SegmentationView()
}
