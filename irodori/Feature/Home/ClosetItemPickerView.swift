//
//  ClosetItemPickerView.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/18.
//

import SwiftUI

struct ClosetItemPickerView: View {
    let closetItems: [ClosetItem]
    let isLoading: Bool
    let onSelect: (ClosetItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    private var topsItems: [ClosetItem] {
        closetItems.filter { $0.item_type == "トップス" }
    }

    private var bottomsItems: [ClosetItem] {
        closetItems.filter { $0.item_type == "ボトムス" }
    }

    private var currentItems: [ClosetItem] {
        selectedTab == 0 ? topsItems : bottomsItems
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabSegmentView

                Divider()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if currentItems.isEmpty {
                    Text("アイテムが見つかりませんでした")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(currentItems) { item in
                                itemCell(item)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("アイテムを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var tabSegmentView: some View {
        HStack(spacing: 0) {
            tabButton(title: "トップス", index: 0)
            tabButton(title: "ボトムス", index: 1)
        }
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
                    .foregroundStyle(selectedTab == index ? .black : .gray)

                Rectangle()
                    .fill(selectedTab == index ? Color.black : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func itemCell(_ item: ClosetItem) -> some View {
        Button {
            onSelect(item)
            dismiss()
        } label: {
            VStack(spacing: 6) {
                CachedAsyncImage(
                    url: item.image_url.flatMap { URL(string: $0) }
                ) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.15)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .clipped()

                VStack(spacing: 2) {
                    if let category = item.category {
                        Text(category)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    if let color = item.color {
                        Text(color)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
