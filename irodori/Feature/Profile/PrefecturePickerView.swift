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
    /// 選択時に呼ばれる。選んだ Prefecture を渡す。呼び出し後に dismiss する.
    let onSelect: (Prefecture) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Prefecture.grouped, id: \.region) { entry in
                Section(entry.region.rawValue) {
                    ForEach(entry.prefectures) { prefecture in
                        Button {
                            Haptic.selection()
                            onSelect(prefecture)
                            dismiss()
                        } label: {
                            HStack {
                                Text(prefecture.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if prefecture.code == selectedCode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("お住まいの地域")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrefecturePickerView(selectedCode: "13", onSelect: { _ in })
    }
}
