//
//  CalendarDaySheets.swift
//  irodori
//
//  カレンダーの日タップから開くモーダル2種。
//  - CalendarDayOutfitsSheet: 同日に複数のコーデ (記録N件 + 予定/採用) がある日の切り替え選択
//    (ハーフモーダル)。Sandbox (CalendarMultiCoordSandbox) で検証した本命案の本番化。
//  - CalendarDaySuggestionSheet: その日のコーデ候補10件 (本命+入替9) の2列グリッド。
//    コーデ詳細と同じ全画面モーダル (fullScreenCover + NavigationStack) で画像の視認性を優先。
//    既存の plan API (start_date 指定) を1日分だけ使い、サーバ改修なしで提案を出す。
//    空き日 = そのまま予定にする / 予定ありの日 = replacing で開き予定を差し替える。
//

import SwiftUI
import Kingfisher

// MARK: - 日別一覧シート (同日複数コーデの切り替え)

struct CalendarDaySheetData: Identifiable {
    let date: String                         // YYYY-MM-DD
    let dateLabel: String                    // 例: "8月12日"
    let records: [CoordinateListResponse]    // 着用記録 (0件以上)
    let outfit: CalendarOutfit?              // 予定 or 採用 (高々1件)
    /// true: 開いたらすぐ選択 (まとめて削除) の状態にする (日付の長押しから)
    var startEditing: Bool = false
    var id: String { date }
}

struct CalendarDayOutfitsSheet: View {
    let data: CalendarDaySheetData
    let onSelectRecord: (CoordinateListResponse) -> Void
    let onSelectOutfit: (CalendarOutfit) -> Void
    /// 非 nil のとき、予定コーデを候補一覧から選び直す導線を出す (予定ありの日のみ)
    var onShowCandidates: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var selected: Set<String> = []
    @State private var confirmDelete = false
    @State private var deleting = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var totalCount: Int { data.records.count + (data.outfit == nil ? 0 : 1) }
    private var deletableIds: [String] { data.records.compactMap { ($0.id ?? "").isEmpty ? nil : $0.id } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(data.dateLabel)のコーデ")
                        .font(.system(size: 17, weight: .bold))
                    Text("\(totalCount)件")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    // 撮った記録を選んでまとめて削除 (予定・採用は対象外)
                    if !deletableIds.isEmpty {
                        Button(editing ? "完了" : "編集") {
                            Haptic.selection()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                editing.toggle()
                                if !editing { selected = [] }
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(minHeight: 44)
                    }
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(data.records.enumerated()), id: \.offset) { index, record in
                        if let imageURL = record.displayImageURL {
                            let id = record.id ?? ""
                            tile(imageURL: imageURL, label: data.records.count > 1 ? "記録\(index + 1)" : "記録",
                                 selected: editing && !id.isEmpty ? selected.contains(id) : nil) {
                                if editing {
                                    guard !id.isEmpty else { return }
                                    if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
                                    return
                                }
                                dismiss()
                                onSelectRecord(record)
                            }
                        }
                    }
                    if let outfit = data.outfit {
                        tile(
                            imageURL: outfit.image_url,
                            label: outfit.isAdopted ? "採用" : "予定",
                            dashed: !outfit.isAdopted,
                            check: outfit.isAdopted
                        ) {
                            guard !editing else { return }
                            dismiss()
                            onSelectOutfit(outfit)
                        }
                        .opacity(editing ? 0.4 : 1)
                    }
                }
                if editing {
                    Button {
                        Haptic.impact(.medium)
                        confirmDelete = true
                    } label: {
                        Text(selected.isEmpty ? "削除するコーデを選んでください" : "\(selected.count)件を削除")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected.isEmpty ? Color.gray.opacity(0.4) : Color.red, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selected.isEmpty || deleting)
                    .padding(.top, 4)
                }
                // 予定ありの日は、この日の候補一覧 (10件) から選び直せる
                if data.outfit != nil, let onShowCandidates {
                    Button {
                        Haptic.selection()
                        dismiss()
                        onShowCandidates()
                    } label: {
                        HStack(spacing: 4) {
                            Text("予定コーデを別の候補から選び直す")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if data.startEditing && !deletableIds.isEmpty { editing = true }
        }
        .confirmationDialog("\(selected.count)件のコーデを削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) { Task { await deleteSelected() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("写真の記録が消えます。クローゼットの服は残ります。元に戻せません")
        }
        .overlay {
            if deleting { ProgressView().controlSize(.large) }
        }
    }

    private func deleteSelected() async {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        guard !selected.isEmpty, !uid.isEmpty else { return }
        deleting = true
        defer { deleting = false }
        let result = await BulkDeleteClient().deleteCoordinates(uid: uid, ids: Array(selected))
        if !result.deleted.isEmpty {
            Haptic.notify(.success)
            NotificationCenter.default.post(name: .coordinateDidChange, object: nil)
        }
        if result.failed.isEmpty {
            ToastManager.shared.show("\(result.deleted.count)件のコーデを削除しました")
            dismiss()
        } else {
            selected = Set(result.failed)
            ToastManager.shared.show("\(result.failed.count)件を削除できませんでした。もう一度お試しください")
        }
    }

    private func tile(
        imageURL: String,
        label: String,
        dashed: Bool = false,
        check: Bool = false,
        selected: Bool? = nil,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            Haptic.selection()
            onTap()
        } label: {
            VStack(spacing: 5) {
                KFImage(URL(string: imageURL))
                    .resizable()
                    .placeholder { Color.gray.opacity(0.12) }
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(3 / 4, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        if dashed {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    Color.black.opacity(0.4),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                )
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if check {
                            AdoptedCheckBadge()
                                .padding(5)
                        }
                    }
                    // 編集中: 選択の印
                    .overlay(alignment: .topTrailing) {
                        if let selected {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(selected ? Color.black : Color.white)
                                .background(Circle().fill(selected ? Color.white : Color.black.opacity(0.25)).padding(1))
                                .padding(5)
                        }
                    }
                    .overlay {
                        if selected == true {
                            RoundedRectangle(cornerRadius: 10).strokeBorder(Color.black, lineWidth: 2)
                        }
                    }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 採用済みの視覚言語: 黒丸に白チェック (セル / シート / 一覧で共通)
struct AdoptedCheckBadge: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle().fill(Color.black)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }
}

// MARK: - その日の提案シート (空き日タップからの提案体験)

struct CalendarDaySuggestionData: Identifiable {
    let date: String         // YYYY-MM-DD
    let dateLabel: String    // 例: "8月15日"
    /// true = 予定ありの日からの「選び直し」(保存すると既存の予定を差し替える)
    var replacing: Bool = false
    var id: String { date }
}

struct CalendarDaySuggestionSheet: View {
    let data: CalendarDaySuggestionData
    /// 提案の取得 (CalendarViewModel.suggest へ委譲)
    let load: () async -> OutfitPlanDay?
    /// 「この日の予定にする」(予定コーデとして保存)
    let onPlan: (DailyRecommendationItem) async -> Bool
    /// 「1週間まとめて提案」への導線 (シートを閉じてからプランナーへ)
    let onOpenPlanner: () -> Void

    private enum LoadState {
        case loading
        case failed
        case loaded(OutfitPlanDay)
    }

    @State private var state: LoadState = .loading
    @State private var savingID: String? = nil
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                switch state {
                case .loading:
                    loadingRow
                case .failed:
                    failedRow
                case .loaded(let day):
                    if let line = day.day_line, !line.isEmpty {
                        Text(line)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    candidatesGrid(day)
                    // 差し替え文脈では焦点を絞るため、まとめ提案への誘導は出さない
                    if !data.replacing {
                        plannerLink
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle("コーデ候補")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") { dismiss() }
                    .disabled(savingID != nil)
            }
        }
        .task { await loadSuggestion() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            PartnerIconImage(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(data.dateLabel)に着るなら")
                    .font(.system(size: 17, weight: .bold))
                Text(data.replacing
                     ? "気に入る候補があれば、いまの予定と差し替えられます"
                     : "相棒が天気と手持ちからコーデを提案します")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if case .loaded(let day) = state, let weather = day.weather {
                DailyMiniWeatherBadge(weather: weather)
            }
        }
    }

    private var loadingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("コーデを考えています…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 140)
        .padding(.bottom, 40)
    }

    private var failedRow: some View {
        VStack(spacing: 10) {
            Text("提案を取得できませんでした")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button {
                state = .loading
                Task { await loadSuggestion() }
            } label: {
                Text("再試行する")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 140)
        .padding(.bottom, 32)
    }

    /// 本命 + 入替候補 (計10件) を軸ラベル (堅実/挑戦/気分転換) 付きの2列グリッドで見せる。
    /// 全画面モーダルの空間を活かし、画像を大きく・10件を縦に一覧できるようにする
    private func candidatesGrid(_ day: OutfitPlanDay) -> some View {
        let candidates = [day.item] + day.alternates
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                candidateCard(candidate, isPrimary: index == 0)
            }
        }
    }

    private func candidateCard(_ candidate: OutfitPlanCandidate, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    KFImage(URL(string: candidate.item.image_url))
                        .resizable()
                        .placeholder { Color.gray.opacity(0.12) }
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(axisLabel(candidate.alt_tag, isPrimary: isPrimary))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(candidate.item.reason ?? candidate.item.vibe)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                savePlan(candidate.item)
            } label: {
                Text(savingID == candidate.id
                     ? "保存中…"
                     : (data.replacing ? "この予定に変更する" : "この日の予定にする"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(savingID != nil)
        }
    }

    private var plannerLink: some View {
        Button {
            Haptic.selection()
            dismiss()
            onOpenPlanner()
        } label: {
            HStack(spacing: 4) {
                Text("1週間ぶんまとめて提案してもらう")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    /// 先頭のみ「本命」。以降は軸ラベル、軸が無い候補 (4件目以降) は「候補」に落とす
    private func axisLabel(_ altTag: String?, isPrimary: Bool) -> String {
        if isPrimary { return "本命" }
        switch altTag {
        case "steady": return "堅実"
        case "challenge": return "挑戦"
        case "change": return "気分転換"
        default: return "候補"
        }
    }

    private func loadSuggestion() async {
        if let day = await load() {
            state = .loaded(day)
        } else {
            state = .failed
        }
    }

    private func savePlan(_ item: DailyRecommendationItem) {
        guard savingID == nil else { return }
        Haptic.impact(.medium)
        savingID = item.id
        Task { @MainActor in
            let ok = await onPlan(item)
            savingID = nil
            if ok {
                Haptic.notify(.success)
                ToastManager.shared.show(
                    data.replacing
                        ? "\(data.dateLabel)の予定コーデを変更しました"
                        : "\(data.dateLabel)の予定コーデに入れました",
                    style: .normal
                )
                dismiss()
            }
        }
    }
}

// MARK: - Preview

private func previewLoadDay() async -> OutfitPlanDay? {
    let result = try? await MockRecommendationPlanClient().plan(
        uid: "preview", gender: .male, days: 2, startDate: "2026-08-20",
        prefectureCode: nil, candidatesPerDay: 10
    )
    if case .success(let response) = result {
        return response.days.first
    }
    return nil
}

#Preview("候補10件 (空き日)") {
    NavigationStack {
        CalendarDaySuggestionSheet(
            data: .init(date: "2026-08-20", dateLabel: "8月20日"),
            load: { await previewLoadDay() },
            onPlan: { _ in true },
            onOpenPlanner: {}
        )
    }
}

#Preview("候補10件 (予定の選び直し)") {
    NavigationStack {
        CalendarDaySuggestionSheet(
            data: .init(date: "2026-08-20", dateLabel: "8月20日", replacing: true),
            load: { await previewLoadDay() },
            onPlan: { _ in true },
            onOpenPlanner: {}
        )
    }
}
