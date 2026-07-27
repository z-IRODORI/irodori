//
//  PrefecturePickerView.swift
//  irodori
//
//  47都道府県を地方別セクション付きリストで提示し、選択結果を呼び出し側へ返す.
//

import SwiftUI

struct PrefecturePickerView: View {
    /// 現在の選択コード (ハイライト表示用)。"01"〜"47"
    let selectedCode: String?
    /// 別枠で登録済みのコード。グレーアウトして重複登録を防ぐ (selectedCode とは別扱い)
    var registeredCodes: Set<String> = []
    /// ナビゲーションタイトル (プロフィールの複数場所登録では「場所を追加」等に差し替える)
    var title: String = "お住まいの地域"
    /// 選択時に呼ばれる。選んだ Prefecture を渡す。呼び出し後に dismiss する.
    let onSelect: (Prefecture) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Prefecture.grouped, id: \.region) { entry in
                Section(entry.region.rawValue) {
                    ForEach(entry.prefectures) { prefecture in
                        let isRegistered = registeredCodes.contains(prefecture.code) && prefecture.code != selectedCode
                        Button {
                            Haptic.selection()
                            onSelect(prefecture)
                            dismiss()
                        } label: {
                            HStack {
                                Text(prefecture.name)
                                    .foregroundStyle(isRegistered ? .secondary : .primary)
                                Spacer()
                                if prefecture.code == selectedCode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.orange)
                                } else if isRegistered {
                                    Text("登録済み")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(isRegistered)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrefecturePickerView(selectedCode: "13", onSelect: { _ in })
    }
}
