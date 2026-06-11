//
//  OutfitCollageSection.swift
//  irodori
//
//  「クローゼットでコーデ」セクション。
//  クローゼットのアイテムをバックエンドで合成したコーデコラージュを表示し、
//  タップ / CTA で詳細モーダル (アイテム差し替え・シャッフル) を開く。
//

import SwiftUI
import Kingfisher

struct OutfitCollageSection: View {
    let response: OutfitCollageResponse?
    let isLoading: Bool
    let hasError: Bool
    let onOpenDetail: () -> Void
    let onRetry: () -> Void

    var body: some View {
        // 生成不可 (クローゼット空など) の場合はセクションごと非表示
        if !isLoading && !hasError && !(response?.isDisplayable ?? false) {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader
                content
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("クローゼットでコーデ")
                .font(.system(size: 20, weight: .bold))
            Text("持っている服で今日の組み合わせ")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            skeleton
        } else if let r = response, r.isDisplayable {
            collageCard(r)
        } else {
            errorState
        }
    }

    private func collageCard(_ r: OutfitCollageResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            KFImage(URL(string: r.collage_url))
                .placeholder {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.12))
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                }
                .resizable()
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    Haptic.impact(.soft)
                    onOpenDetail()
                }

            itemChips(r.items)

            Button(action: {
                Haptic.impact(.soft)
                onOpenDetail()
            }) {
                Label("コーデを組み替える", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func itemChips(_ items: [OutfitCollageItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 4) {
                        Text(item.slotDisplayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(item.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Skeleton

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.12))
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.12))
                .frame(height: 44)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Error

    private var errorState: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 20))
                .foregroundStyle(Color.gray.opacity(0.5))
            VStack(alignment: .leading, spacing: 4) {
                Text("読み込めませんでした")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                Button(action: onRetry) {
                    Text("再試行する")
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                        .underline()
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    ScrollView {
        OutfitCollageSection(
            response: .mock(),
            isLoading: false,
            hasError: false,
            onOpenDetail: {},
            onRetry: {}
        )
        .padding(24)
    }
    .background(Color.gray.opacity(0.08))
}
