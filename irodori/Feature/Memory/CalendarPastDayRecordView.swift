//
//  CalendarPastDayRecordView.swift
//  irodori
//
//  カレンダーの過去の日 (記録なし) を押したとき: 「この日に着た服」をクローゼットから選んで残す。
//  保存は api/home/owned-first/wear (提案なしの記録)。服を1枚の画像にまとめてカレンダーに載せ、
//  相棒の「着ると決めた」記録 (発見・ミッション) にも数える。
//

import Kingfisher
import SwiftUI

struct CalendarPastDayRecordView: View {
    let data: CalendarDaySuggestionData
    var onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [ClosetItem] = []
    @State private var isLoading = true
    @State private var selected: [String: ClosetItem] = [:]   // slot -> 選んだ服 (スロットごとに1点)
    @State private var isSaving = false
    @State private var errorText: String?

    private static let slots: [(key: String, label: String, category: ClothingCategory)] = [
        ("tops", "トップス", .tops), ("bottoms", "ボトムス", .bottoms),
        ("outer", "アウター", .outer), ("shoes", "シューズ", .shoes),
    ]

    private var uid: String { UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    PartnerIconImage(size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(data.dateLabel)は何を着た？")
                            .font(.system(size: 18, weight: .bold))
                        Text("着た服を選ぶと、カレンダーに残るよ")
                            .font(.system(size: 12))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if items.isEmpty {
                    Text("クローゼットに服がまだありません")
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.muted)
                } else {
                    ForEach(Self.slots, id: \.key) { slot in
                        let list = items.filter { $0.mainItemType == slot.category.rawValue }
                        if !list.isEmpty { slotRow(slot.key, label: slot.label, list: list) }
                    }
                }
                if let errorText {
                    Text(errorText).font(.system(size: 12)).foregroundStyle(.red)
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(RenewalTokens.ground)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await save() }
            } label: {
                if isSaving { ProgressView().tint(.white) } else {
                    Text(selected.isEmpty ? "服を選んでください" : "\(selected.count)点で記録する")
                }
            }
            .buttonStyle(RenewalPrimaryButtonStyle(filled: !selected.isEmpty))
            .disabled(selected.isEmpty || isSaving)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(RenewalTokens.ground)
        }
        .navigationTitle("着た服を記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("閉じる") { dismiss() }.foregroundStyle(.black)
            }
        }
        .task { await load() }
    }

    private func slotRow(_ key: String, label: String, list: [ClosetItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.system(size: 14, weight: .bold))
                Spacer()
                if selected[key] != nil {
                    Button("選び直す") { withAnimation { selected[key] = nil } }
                        .font(.system(size: 12))
                        .foregroundStyle(RenewalTokens.muted)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(list) { item in
                        let on = selected[key]?.id == item.id
                        Button {
                            Haptic.selection()
                            withAnimation(.easeOut(duration: 0.15)) { selected[key] = on ? nil : item }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Group {
                                    if let s = item.image_url, let url = URL(string: s) {
                                        KFImage(url).resizable().scaledToFit().padding(6)
                                    } else {
                                        Image(systemName: "tshirt").foregroundStyle(RenewalTokens.muted)
                                    }
                                }
                                .frame(width: 84, height: 84)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(on ? RenewalTokens.ink : RenewalTokens.border, lineWidth: on ? 2 : 1))
                                if on {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(RenewalTokens.ink, .white)
                                        .padding(4)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.color ?? "") \(item.category ?? item.item_type)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func load() async {
        defer { isLoading = false }
        guard !uid.isEmpty, let result = try? await ClosetClient().get(uid: uid, itemType: nil),
              case .success(let res) = result else { return }
        items = res.items
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let picked = Self.slots.compactMap { s in selected[s.key].map { (s.key, $0) } }
        let pieces = picked.map { key, item in
            OwnedFirstBoardPiece(slot: key, image_url: item.image_url,
                                 label: "\(item.color ?? "") \(item.category ?? "")".trimmingCharacters(in: .whitespaces),
                                 owned: true)
        }
        do {
            let result = try await OwnedFirstHomeClient().recordWorn(
                uid: uid, targetDate: data.date, pieces: pieces, itemIds: picked.map { $0.1.id })
            if case .success = result {
                Haptic.notify(.success)
                await onSaved()
                dismiss()
                return
            }
        } catch {}
        errorText = "保存できませんでした。時間をおいてもう一度お試しください"
    }
}
