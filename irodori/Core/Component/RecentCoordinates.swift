//
//  ReccentCoordinates.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import SwiftUI
import Kingfisher

struct RecentCoordinates: View {
    let recentCoordinates: [RecentCoordinate]
    let isEditMode: Bool
    let onToggleEditMode: () -> Void
    let onDeleteRequest: (String) -> Void
    let onTapCoordinate: (RecentCoordinate) -> Void

    @Environment(FavoritesStore.self) private var favoritesStore

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("直近のコーデ")
                    .font(.system(size: 20, weight: .bold))

                Spacer()

                if !recentCoordinates.isEmpty {
                    Button(action: onToggleEditMode) {
                        Text(isEditMode ? "キャンセル" : "編集")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            if recentCoordinates.isEmpty {
                Text("コーデが存在しません...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Spacer().frame(width: 12)
                        ForEach(recentCoordinates, id: \.self) { coordinate in
                            RecentCoordinateCard(
                                coordinate: coordinate,
                                isEditMode: isEditMode,
                                onDelete: {
                                    onDeleteRequest(coordinate.id)
                                }
                            )
                        }
                        Spacer().frame(width: 12)
                    }
                }
            }
        }
    }

    private func RecentCoordinateCard(
        coordinate: RecentCoordinate,
        isEditMode: Bool,
        onDelete: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isEditMode else { return }
            Haptic.impact(.soft)
            onTapCoordinate(coordinate)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    KFImage(URL(string: coordinate.image_url))
                        .placeholder { Color.gray.opacity(0.3) }
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fit)
                        .frame(width: 110)
                        .overlay(alignment: .bottomLeading) {
                            if !isEditMode {
                                favoriteButton(for: coordinate)
                                    .padding(6)
                            }
                        }

                    Text("\(coordinate.date)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 10)
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if isEditMode {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .background(Circle().fill(.red))
                    }
                    .offset(x: -4, y: 4)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isEditMode)
    }

    private func favoriteButton(for coordinate: RecentCoordinate) -> some View {
        let isFav = favoritesStore.isFavorite(kind: .self, targetId: coordinate.id)
        return FavoriteToggleButton(isFavorite: isFav, size: 12, padding: 7) {
            Task {
                await favoritesStore.toggle(
                    kind: .self,
                    targetId: coordinate.id,
                    imageURL: coordinate.image_url,
                    date: coordinate.date
                )
            }
        }
    }
}

#Preview {
    RecentCoordinates(
        recentCoordinates: [],
        isEditMode: false,
        onToggleEditMode: {},
        onDeleteRequest: { _ in },
        onTapCoordinate: { _ in }
    )
    .environment(FavoritesStore(client: MockFavoriteClient()))
}
