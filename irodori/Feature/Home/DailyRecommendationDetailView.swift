//
//  DailyRecommendationDetailView.swift
//  irodori
//
//  推薦コーデの詳細モーダル。kind=pool は「これを今日着る」ボタンで着用記録を送信、
//  kind=self は自分のお気に入りコーデなので着用ボタンは出さない。
//

import SwiftUI
import Kingfisher

struct DailyRecommendationDetailView: View {
    let item: DailyRecommendationItem
    let onWear: (DailyRecommendationItem) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(FavoritesStore.self) private var favoritesStore

    @State private var isMarking = false
    @State private var marked = false
    @State private var errorText: String?
    @State private var showAddToCalendar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    KFImage(URL(string: item.image_url))
                        .resizable()
                        .placeholder { Rectangle().fill(Color.gray.opacity(0.15)) }
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                    favoriteButton
                        .padding(10)
                }

                if item.kindEnum == .self {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("お気に入りに登録した自分のコーデ")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.pink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.pink.opacity(0.08))
                    .overlay(
                        Capsule().stroke(Color.pink.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }

                if let reason = item.reason, !reason.isEmpty {
                    sectionTitle("おすすめ理由")
                    Text(reason).font(.body)
                }

                if item.kindEnum == .pool, hasCoordItems {
                    sectionTitle("コーデ構成")
                    coordItemsSection
                }

                if !item.vibe.isEmpty {
                    sectionTitle("印象")
                    Text(item.vibe)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                addToCalendarButton

                if item.kindEnum == .pool {
                    wearButton
                }

                if let e = errorText {
                    Text(e).font(.caption).foregroundColor(.red)
                }
            }
            .padding(20)
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddToCalendar) {
            AddToCalendarSheet(
                kind: item.kindEnum == .self ? "self" : "pool",
                targetId: item.pool_id,
                imageURL: item.image_url,
                source: "detail"
            )
            .presentationDetents([.height(300)])
        }
    }

    // 予定コーデとしてカレンダーにストックする (主CTA)
    private var addToCalendarButton: some View {
        Button {
            Haptic.impact(.medium)
            showAddToCalendar = true
        } label: {
            Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }

    private var favoriteButton: some View {
        let kind = item.kindEnum
        let isFav = favoritesStore.isFavoriteRespectingSession(
            kind: kind,
            targetId: item.pool_id,
            fallback: item.is_favorite
        )
        return FavoriteToggleButton(isFavorite: isFav, size: 16, padding: 10) {
            Task {
                await favoritesStore.setFavorite(
                    !isFav,
                    kind: kind,
                    targetId: item.pool_id,
                    imageURL: item.image_url
                )
            }
        }
    }

    private var hasCoordItems: Bool {
        ["tops", "bottoms", "outer", "accessory"].contains { key in
            if let v = item.items[key] ?? nil, !v.isEmpty { return true }
            return false
        }
    }

    private var coordItemsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(["tops", "bottoms", "outer", "accessory"], id: \.self) { key in
                if let v = item.items[key] ?? nil, !v.isEmpty {
                    HStack(alignment: .top) {
                        Text(labelFor(key))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(v).font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }

    private func labelFor(_ key: String) -> String {
        switch key {
        case "tops": return "トップス"
        case "bottoms": return "ボトムス"
        case "outer": return "アウター"
        case "accessory": return "小物"
        default: return key
        }
    }

    @ViewBuilder
    private var wearButton: some View {
        if marked {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("今日のコーデに記録しました")
            }
            .foregroundColor(.green)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        } else {
            Button {
                Haptic.impact(.medium)
                Task {
                    isMarking = true
                    errorText = nil
                    let ok = await onWear(item)
                    isMarking = false
                    if ok {
                        Haptic.notify(.success)
                        marked = true
                    } else {
                        Haptic.notify(.error)
                        errorText = "記録に失敗しました。時間をおいて再度お試しください。"
                    }
                }
            } label: {
                HStack {
                    if isMarking { ProgressView().tint(.black) }
                    Text(isMarking ? "送信中…" : "これを今日着る").font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .foregroundColor(.black)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2), lineWidth: 1))
                .cornerRadius(10)
            }
            .disabled(isMarking)
        }
    }
}

#Preview {
    NavigationStack {
        DailyRecommendationDetailView(
            item: DailyRecommendationResponse.mock().recommendations[0],
            onWear: { _ in
                try? await Task.sleep(nanoseconds: 500_000_000)
                return true
            }
        )
        .environment(FavoritesStore(client: MockFavoriteClient()))
    }
}
