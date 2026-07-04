//
//  OutfitCollageDetailView.swift
//  irodori
//
//  コーデコラージュ詳細モーダル。
//  - コラージュ画像の拡大表示
//  - スロット (トップス/ボトムス/...) ごとのアイテム差し替え
//  - シャッフル再生成
//  差し替え候補はレスポンスの candidates を使うため追加通信なし。
//

import SwiftUI
import Kingfisher

struct OutfitCollageDetailView: View {
    let viewModel: HomeViewModel

    @State private var pickerSlot: PickerSlot? = nil
    @State private var showingClosetPicker = false
    @State private var showingLayoutEditor = false
    @State private var webLink: HomeWebLink? = nil

    private struct PickerSlot: Identifiable {
        let slot: String
        let displayName: String
        var id: String { slot }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let response = viewModel.outfitCollage {
                VStack(alignment: .leading, spacing: 20) {
                    collageImage(response)
                    VStack(spacing: 10) {
                        shuffleButton
                        fromItemButton
                        editLayoutButton
                    }
                    itemList(response)
                    recommendationsSection
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .background(Color.gray.opacity(0.08))
        .navigationTitle("クローゼットでコーデ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pickerSlot) { picker in
            OutfitCollageItemPickerView(
                slotDisplayName: picker.displayName,
                candidates: viewModel.outfitCollage?.candidates[picker.slot] ?? [],
                selectedItemId: viewModel.outfitCollage?.items.first { $0.slot == picker.slot }?.id,
                onSelect: { item in
                    Task { await viewModel.swapOutfitCollageItem(slot: picker.slot, to: item) }
                }
            )
        }
        .sheet(isPresented: $showingClosetPicker) {
            ClosetItemPickerView(
                closetItems: viewModel.closetItems,
                isLoading: viewModel.isLoadingCloset,
                onSelect: { item in
                    showingClosetPicker = false
                    Task { await viewModel.generateOutfitFromItem(item) }
                }
            )
        }
        .sheet(item: $webLink) { link in
            WebViewContainer(url: link.url)
        }
        .sheet(isPresented: $showingLayoutEditor) {
            OutfitCollageLayoutEditView(onSaved: { response in
                viewModel.outfitCollage = response
            })
        }
        .onAppear {
            Task { await viewModel.loadOutfitRecommendations() }
        }
    }

    // MARK: - Collage

    private func collageImage(_ response: OutfitCollageResponse) -> some View {
        KFImage(URL(string: response.collage_url))
            .placeholder {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.12))
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
            }
            .resizable()
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            .overlay {
                if viewModel.isRegeneratingOutfitCollage {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("コーデを組み替え中…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
    }

    // MARK: - Shuffle

    private var shuffleButton: some View {
        Button(action: {
            Haptic.impact(.soft)
            Task { await viewModel.shuffleOutfitCollage() }
        }) {
            Label("シャッフル", systemImage: "shuffle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(viewModel.isRegeneratingOutfitCollage)
    }

    // MARK: - Items

    private func itemList(_ response: OutfitCollageResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使っているアイテム")
                .font(.system(size: 15, weight: .semibold))

            VStack(spacing: 0) {
                ForEach(Array(response.items.enumerated()), id: \.element.id) { idx, item in
                    itemRow(item, canSwap: (response.candidates[item.slot]?.count ?? 0) > 1)
                    if idx < response.items.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }

    private func itemRow(_ item: OutfitCollageItem, canSwap: Bool) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(
                url: item.image_url.isEmpty ? nil : URL(string: item.image_url)
            ) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.12)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.slotDisplayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if item.is_standard {
                        Text("おすすめ")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text(item.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            if canSwap {
                Button(action: {
                    Haptic.impact(.soft)
                    pickerSlot = PickerSlot(slot: item.slot, displayName: item.slotDisplayName)
                }) {
                    Text("変更")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .disabled(viewModel.isRegeneratingOutfitCollage)
            }
        }
        .padding(12)
    }

    // MARK: - アイテムから作る

    private var fromItemButton: some View {
        Button {
            Haptic.impact(.soft)
            showingClosetPicker = true
            Task { await viewModel.loadClosetItemsIfNeeded() }
        } label: {
            Label("持っているアイテムから作る", systemImage: "tshirt")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
        .disabled(viewModel.isRegeneratingOutfitCollage)
    }

    // MARK: - 配置を編集

    private var editLayoutButton: some View {
        Button {
            Haptic.impact(.soft)
            showingLayoutEditor = true
        } label: {
            Label("大きさ・配置を編集", systemImage: "square.on.square.dashed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
        .disabled(viewModel.isRegeneratingOutfitCollage)
    }

    // MARK: - おすすめ商品 (アフィリエイト)

    @ViewBuilder
    private var recommendationsSection: some View {
        if viewModel.isLoadingOutfitRecommendations {
            VStack(alignment: .leading, spacing: 14) {
                recommendHeader
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        } else if let rec = viewModel.outfitRecommendations, !rec.items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                recommendHeader
                ForEach(Array(rec.items.enumerated()), id: \.offset) { _, item in
                    ClosetBridgeItemRow(
                        item: item,
                        onTapProduct: { product in openWeb(product.url) },
                        onTapZozo: { it in openWeb(it.zozo_search_url) }
                    )
                }
            }
        }
        // 取得失敗 or 0件はセクションごと非表示 (コーデ表示を妨げない)
    }

    private var recommendHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("このコーデにおすすめ")
                .font(.system(size: 18, weight: .bold))
            Text("買い足すともっと楽しめるアイテム")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openWeb(_ urlString: String) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }
        Haptic.impact(.soft)
        webLink = HomeWebLink(url: url)
    }
}

// MARK: - アイテム差し替えピッカー

struct OutfitCollageItemPickerView: View {
    let slotDisplayName: String
    let candidates: [OutfitCollageItem]
    let selectedItemId: String?
    let onSelect: (OutfitCollageItem) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    Text("アイテムが見つかりませんでした")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(candidates) { item in
                                itemCell(item)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("\(slotDisplayName)を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func itemCell(_ item: OutfitCollageItem) -> some View {
        let isSelected = item.id == selectedItemId
        return Button {
            Haptic.impact(.soft)
            onSelect(item)
            dismiss()
        } label: {
            VStack(spacing: 6) {
                CachedAsyncImage(
                    url: item.image_url.isEmpty ? nil : URL(string: item.image_url)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
                )

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

#Preview {
    NavigationStack {
        OutfitCollageDetailView(
            viewModel: {
                let vm = HomeViewModel(outfitCollageClient: MockOutfitCollageClient())
                vm.outfitCollage = .mock()
                return vm
            }()
        )
    }
}
