//
//  DailyRecommendationDetailView.swift
//  irodori
//
//  推薦コーデの詳細モーダル。タップして「これを今日着る」ボタンで着用記録を送信。
//

import SwiftUI
import Kingfisher

struct DailyRecommendationDetailView: View {
    let item: DailyRecommendationItem
    let onWear: (DailyRecommendationItem) async -> Bool
    @Environment(\.dismiss) private var dismiss

    @State private var isMarking = false
    @State private var marked = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KFImage(URL(string: item.image_url))
                    .resizable()
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                    }
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)

                if let reason = item.reason, !reason.isEmpty {
                    sectionTitle("おすすめ理由")
                    Text(reason)
                        .font(.body)
                }

                sectionTitle("コーデ構成")
                ForEach(["tops", "bottoms", "outer", "accessory"], id: \.self) { key in
                    if let v = item.items[key] ?? nil, !v.isEmpty {
                        HStack(alignment: .top) {
                            Text(labelFor(key))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .leading)
                            Text(v)
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }

                if !item.vibe.isEmpty {
                    sectionTitle("印象")
                    Text(item.vibe)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                wearButton

                if let e = errorText {
                    Text(e)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(20)
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
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
                    if isMarking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isMarking ? "送信中…" : "これを今日着る")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange)
                .foregroundColor(.white)
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
    }
}
