//
//  CoordinateGridView.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/14.
//

import SwiftUI

struct CoordinateGridView: View {
    let coordinates: [CoordinateRecommend]
    let onTapCoordinate: (Int) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        if coordinates.isEmpty {
            emptyStateView
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(coordinates.indices, id: \.self) { index in
                        coordinateCell(coordinate: coordinates[index], index: index)
                    }
                }
            }
            .frame(height: 520)
        }
    }

    private func coordinateCell(coordinate: CoordinateRecommend, index: Int) -> some View {
        Button(action: { onTapCoordinate(index) }) {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack {
                        if coordinate.coordinate_image_path.hasPrefix("http") {
                            // HTTP URLの場合
                            CachedAsyncImage(url: URL(string: coordinate.coordinate_image_path)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            } placeholder: {
                                Color.gray.opacity(0.15)
                            }
                        } else {
                            // FirebaseStorageの場合
                            FirebaseStorageImage(path: coordinate.coordinate_image_path)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color.gray.opacity(0.1))
                }
                .aspectRatio(3/4, contentMode: .fit)
            }
            .padding(8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(.gray.opacity(0.3))
            Text("コーデが生成されていません")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
