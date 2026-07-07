//
//  AddToCalendarSheet.swift
//  irodori
//
//  コーデをカレンダー (予定コーデ) にストックする日付選択シート。
//  クイックチップ (今日/明日/今週末) + DatePicker で日付を選び、
//  既に予定がある日は「差し替えますか？」を確認してから保存する。
//

import SwiftUI

struct AddToCalendarSheet: View {
    let kind: String        // pool | self
    let targetId: String
    let imageURL: String
    let source: String
    var client: CalendarOutfitClientProtocol = CalendarOutfitClient()
    var onSaved: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var isSaving = false
    @State private var showConflictDialog = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("カレンダーに追加")
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 20)

            HStack(spacing: 8) {
                quickChip("今日", date: Date())
                quickChip("明日", date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
                quickChip("今週末", date: nextSaturday())
            }

            HStack {
                Text("日付を選ぶ")
                    .font(.system(size: 14))
                Spacer()
                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(.black)
            }
            .padding(12)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer(minLength: 0)

            Button {
                Haptic.impact(.medium)
                Task { await save(force: false) }
            } label: {
                HStack {
                    if isSaving { ProgressView().tint(.white) }
                    Text(isSaving ? "追加中…" : "この日に追加")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isSaving)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .confirmationDialog(
            "\(displayDate(selectedDate))にはすでに予定コーデがあります",
            isPresented: $showConflictDialog,
            titleVisibility: .visible
        ) {
            Button("差し替える", role: .destructive) {
                Task { await save(force: true) }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func quickChip(_ label: String, date: Date) -> some View {
        let selected = Calendar.current.isDate(selectedDate, inSameDayAs: date)
        return Button {
            Haptic.impact(.soft)
            selectedDate = date
        } label: {
            Text(label)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.black : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.clear : Color.black.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// 直近の土曜日 (今日が土曜なら今日)
    private func nextSaturday() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0...6 {
            let d = calendar.date(byAdding: .day, value: offset, to: today)!
            if calendar.component(.weekday, from: d) == 7 { return d }
        }
        return today
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func save(force: Bool) async {
        guard !isSaving else { return }
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let dateStr = dateString(selectedDate)
        isSaving = true
        defer { isSaving = false }

        // 競合チェック: 同日に既に予定があれば差し替え確認を挟む
        if !force {
            let comps = Calendar.current.dateComponents([.year, .month], from: selectedDate)
            if let year = comps.year, let month = comps.month,
               let result = try? await client.list(uid: uid, year: year, month: month),
               case .success(let response) = result,
               response.items.contains(where: { $0.date == dateStr }) {
                showConflictDialog = true
                return
            }
        }

        guard let result = try? await client.put(
            uid: uid, date: dateStr, kind: kind, targetId: targetId,
            imageURL: imageURL, source: source
        ), case .success = result else {
            ToastManager.shared.show("カレンダーへの追加に失敗しました")
            return
        }
        Haptic.notify(.success)
        ToastManager.shared.show("\(displayDate(selectedDate))のコーデに追加しました", style: .normal)
        onSaved?(dateStr)
        dismiss()
    }
}

#Preview {
    AddToCalendarSheet(
        kind: "pool",
        targetId: "m_0001",
        imageURL: "https://example.com/1.jpg",
        source: "detail",
        client: MockCalendarOutfitClient()
    )
}
