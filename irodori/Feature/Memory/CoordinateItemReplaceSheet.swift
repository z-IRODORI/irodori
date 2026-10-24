//
//  CoordinateItemReplaceSheet.swift
//  irodori
//
//  コーデの着用アイテムが違っていたとき (解析の検出ミス) に直すシート。
//  クローゼットの服から選んで差し替えるか、コーデから外す。
//

import Kingfisher
import SwiftUI

struct CoordinateItemReplaceSheet: View {
    let item: CoordinateDetailResponse.CoordinateItem
    /// 差し替え先のクローゼットの服 id を受け取り、成功したら true
    var onReplace: (String) async -> Bool
    /// コーデから外す。成功したら true
    var onRemove: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var items: [ClosetItem] = []
    @State private var isLoading = true
    @State private var category: ClothingCategory
    @State private var working = false
    @State private var confirmRemove = false

    init(item: CoordinateDetailResponse.CoordinateItem,
         onReplace: @escaping (String) async -> Bool,
         onRemove: @escaping () async -> Bool) {
        self.item = item
        self.onReplace = onReplace
        self.onRemove = onRemove
        let main = item.item_type.split(separator: "_").first.map(String.init) ?? item.item_type
        _category = State(initialValue: ClothingCategory(rawValue: main) ?? .tops)
    }

    private var filtered: [ClosetItem] {
        items.filter { $0.mainItemType == category.rawValue }
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    current
                    Picker("カテゴリ", selection: $category) {
                        ForEach(ClothingCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                    } else if filtered.isEmpty {
                        Text("クローゼットに\(category.rawValue)がまだありません")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(filtered) { closet in
                                Button {
                                    Haptic.impact(.soft)
                                    Task {
                                        working = true
                                        if await onReplace(closet.id) { dismiss() }
                                        working = false
                                    }
                                } label: {
                                    tile(closet)
                                }
                                .buttonStyle(.plain)
                                .disabled(working)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        confirmRemove = true
                    } label: {
                        Text("このアイテムをコーデから外す")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.top, 8)
                    .disabled(working)
                }
                .padding(20)
            }
            .overlay { if working { ProgressView().controlSize(.large) } }
            .navigationTitle("アイテムを直す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }.foregroundStyle(.black)
                }
            }
            .confirmationDialog("このアイテムをコーデから外しますか？", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("外す", role: .destructive) {
                    Task {
                        working = true
                        if await onRemove() { dismiss() }
                        working = false
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("クローゼットの服は消えません")
            }
            .task { await load() }
        }
    }

    private var current: some View {
        HStack(spacing: 12) {
            Group {
                if let url = URL(string: item.item_image_path), item.item_image_path.hasPrefix("http") {
                    KFImage(url).resizable().scaledToFit().padding(6)
                } else {
                    Image(systemName: "tshirt").foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.gray.opacity(0.08)))
            VStack(alignment: .leading, spacing: 3) {
                Text("いまの\(item.item_type)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("違っていたら、実際に着た服を選んでね")
                    .font(.system(size: 14, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tile(_ closet: ClosetItem) -> some View {
        let isCurrent = closet.id == item.id
        return VStack(spacing: 4) {
            Group {
                if let s = closet.image_url, let url = URL(string: s) {
                    KFImage(url).resizable().scaledToFit().padding(6)
                } else {
                    Image(systemName: "tshirt").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCurrent ? Color.black : Color.gray.opacity(0.2), lineWidth: isCurrent ? 2 : 1))
            Text([closet.color, closet.category].compactMap { $0 }.joined(separator: " "))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityLabel("\(closet.color ?? "") \(closet.category ?? "")に差し替える")
    }

    private func load() async {
        defer { isLoading = false }
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        guard let result = try? await ClosetClient().get(uid: uid, itemType: nil), case .success(let res) = result else { return }
        items = res.items
    }
}
