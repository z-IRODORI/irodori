//
//  DailyRecommendationDetailView.swift
//  irodori
//
//  推薦コーデの詳細モーダル。kind=pool は「今日これを着た」ボタンで着用記録を送信、
//  kind=self は自分のお気に入りコーデなので着用ボタンは出さない。
//
//  2アクションの役割 (混同防止のためラベルとキャプションで結果を明示する):
//  - 着る日を決める   = 未来の意図。予定コーデとしてカレンダーに可視化される
//  - 今日これを着た   = 過去の事実。worn_coordinates に記録され相棒の学習に使われる
//    (カレンダーには表示されない)
//
//  カレンダーの予定コーデから開いた場合 (plannedDate != nil) は文脈が変わる:
//  既にカレンダーにあるので「着る日を決める」を出さず「予定から削除」を出し、
//  着用ボタンは予定日が今日のときだけ出す (未来の予定に「今日着た」は意図が混線するため)。
//

import SwiftUI
import Kingfisher

struct DailyRecommendationDetailView: View {
    let item: DailyRecommendationItem
    let onWear: (DailyRecommendationItem) async -> Bool
    /// カレンダーの予定コーデから開いた場合の予定日 (YYYY-MM-DD)。nil なら通常文脈
    var plannedDate: String? = nil
    /// 予定から削除 (カレンダー文脈のみ)。CalendarViewModel.deletePlanned を包み、
    /// ローカルの plannedByDate も即時更新されるようにする (シート閉鎖では再取得されないため)
    var onDeletePlanned: (() async -> Bool)? = nil
    /// 予定コーデの採用状態と切替 (カレンダー文脈のみ)。
    /// 採用 = 提案のままでも削除でもない第3の状態「その日のコーデとして確定」
    var isAdopted: Bool = false
    var onAdopt: (() async -> Bool)? = nil
    var onUnadopt: (() async -> Bool)? = nil
    /// この日の候補一覧 (10件) から予定を選び直す導線 (カレンダー文脈・今日以降の予定のみ)。
    /// 呼び出し側でこのシートを閉じ、CalendarDaySuggestionSheet (replacing) を開く
    var onShowCandidates: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(MainTabViewModel.self) private var tabViewModel

    @State private var isMarking = false
    @State private var marked = false
    @State private var errorText: String?
    @State private var showAddToCalendar = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var isAdopting = false
    @State private var adoptedState = false
    @State private var webLink: HomeWebLink? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // ハートは左下 (9件グリッドのカードと同じ位置に統一)
                ZStack(alignment: .bottomLeading) {
                    KFImage(URL(string: item.image_url))
                        .resizable()
                        .placeholder { Rectangle().fill(Color.gray.opacity(0.15)) }
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                    if !item.isCloset {
                        favoriteButton
                            .padding(10)
                    }
                }
                // おすすめコーデのグリッドと同じ「使っている手持ちアイテム」アイコンを画像右上に表示。
                // ◯ = 使える手持ちアイテム / 破線 = 手持ちと一致なし (pool コーデのみ)。
                .overlay(alignment: .topTrailing) {
                    if item.kindEnum == .pool {
                        Group {
                            if !item.owned_items.isEmpty {
                                OwnedItemCircles(items: item.owned_items, size: 40, background: .white)
                            } else {
                                NoOwnedItemBadge(size: 40)
                            }
                        }
                        .padding(10)
                    }
                }

                if let plannedDate {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(displayDate(plannedDate))の予定コーデ")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.08))
                    .overlay(
                        Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }

                if item.kindEnum == .self {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("お気に入りに登録した自分のコーデ")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.pink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.pink.opacity(0.08))
                    .overlay(
                        Capsule().stroke(Color.pink.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }

                if let reason = item.reason, !reason.isEmpty {
                    sectionTitle("おすすめ理由")
                    Text(reason).font(.body)
                }

                if item.kindEnum == .pool, hasCoordItems {
                    sectionTitle("コーデ構成")
                    coordItemsSection
                }

                if item.kindEnum == .pool, !item.owned_items.isEmpty || !item.missing_items.isEmpty {
                    sectionTitle("手持ちアイテムでの再現")
                    closetMatchSection
                }

                if !item.vibe.isEmpty {
                    sectionTitle("印象")
                    Text(item.vibe)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 予定コーデ文脈では出さない (既にカレンダーにあり「追加」は意味を成さないため)
                if plannedDate == nil {
                    addToCalendarButton
                }

                // 着用記録はプールのコーデのみ (closet は faiss_idx を持たないため対象外)。
                // 予定コーデ文脈では予定日が今日のときだけ (予定→着た実績への転換として意味を持つ瞬間)
                if item.kind == "pool", plannedDate == nil || plannedDate == todayString {
                    wearButton
                }

                if plannedDate != nil, onAdopt != nil {
                    adoptSection
                }

                if plannedDate != nil, onShowCandidates != nil {
                    showCandidatesButton
                }

                if plannedDate != nil, onDeletePlanned != nil {
                    deletePlannedButton
                }

                if let e = errorText {
                    Text(e).font(.caption).foregroundColor(.red)
                }
            }
            .padding(20)
        }
        .onAppear { adoptedState = isAdopted }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddToCalendar) {
            AddToCalendarSheet(
                kind: item.kind,   // pool | self | closet
                targetId: item.pool_id,
                imageURL: item.image_url,
                source: "detail"
            )
            .presentationDetents([.height(300)])
        }
        // ZOZO検索は medium シート内 push だと表示領域が半分になるため全画面カバーで開く
        .fullScreenCover(item: $webLink) { link in
            WebViewContainer(url: link.url)
        }
        .alert(deleteConfirmTitle, isPresented: $showDeleteConfirm) {
            Button("削除する", role: .destructive) {
                Task { await deletePlanned() }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // 予定コーデとしてカレンダーにストックする (主CTA)。
    // 着用記録ボタンとの混同を防ぐため「未来形のラベル + 行き先のキャプション」で結果を明示する
    private var addToCalendarButton: some View {
        Button {
            Haptic.impact(.medium)
            showAddToCalendar = true
        } label: {
            VStack(spacing: 3) {
                Label("着る日を決める", systemImage: "calendar.badge.plus")
                    .font(.headline)
                Text("カレンダーに予定コーデとして入ります")
                    .font(.system(size: 11))
                    .opacity(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }

    // 採用 (この日のコーデとして確定) の切替。提案(予定)のまま / 削除 に次ぐ第3の状態。
    // 採用済みは ✓ の状態表示 + 控えめな取り消しリンクにして、主役を「採用する」側に置く
    @ViewBuilder
    private var adoptSection: some View {
        if adoptedState {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
                Text("この日のコーデに採用済み")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if onUnadopt != nil {
                    Button {
                        Haptic.selection()
                        toggleAdopt(to: false)
                    } label: {
                        Text(isAdopting ? "変更中…" : "取り消す")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdopting)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.gray.opacity(0.06))
            .cornerRadius(10)
        } else {
            Button {
                Haptic.impact(.medium)
                toggleAdopt(to: true)
            } label: {
                VStack(spacing: 3) {
                    Label(isAdopting ? "保存中…" : "この日のコーデにする", systemImage: "checkmark.circle")
                        .font(.headline)
                    Text("提案から「採用」に変わり、カレンダーと一覧に記録されます")
                        .font(.system(size: 11))
                        .opacity(0.75)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isAdopting)
        }
    }

    private func toggleAdopt(to adopted: Bool) {
        guard !isAdopting else { return }
        let action = adopted ? onAdopt : onUnadopt
        guard let action else { return }
        isAdopting = true
        Task { @MainActor in
            let ok = await action()
            isAdopting = false
            if ok {
                adoptedState = adopted
                Haptic.notify(.success)
                if adopted {
                    ToastManager.shared.show("この日のコーデに採用しました", style: .normal)
                }
            }
        }
    }

    // 別の候補から選び直す (カレンダーの予定コーデ文脈のみ)。
    // 削除→再提案の2手を1手にする: この日の候補一覧へ切り替えて予定を差し替える
    private var showCandidatesButton: some View {
        Button {
            Haptic.impact(.soft)
            onShowCandidates?()
        } label: {
            Label("別の候補から選び直す", systemImage: "rectangle.grid.2x2")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.black)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.25), lineWidth: 1))
        }
    }

    // 予定から削除 (カレンダーの予定コーデ文脈のみ)。
    // ダイアログを挟まず詳細を直接開く導線になったぶん、誤タップ防止の確認アラートを挟む
    private var deletePlannedButton: some View {
        Button {
            Haptic.impact(.medium)
            showDeleteConfirm = true
        } label: {
            HStack {
                if isDeleting { ProgressView().tint(.red) }
                Label("予定から削除", systemImage: "trash")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(.red)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
        }
        .disabled(isDeleting)
    }

    private var deleteConfirmTitle: String {
        guard let plannedDate else { return "予定から削除しますか？" }
        return "\(displayDate(plannedDate))の予定から削除しますか？"
    }

    private func deletePlanned() async {
        guard let onDeletePlanned else { return }
        isDeleting = true
        let ok = await onDeletePlanned()
        isDeleting = false
        if ok {
            Haptic.notify(.success)
            dismiss()
        }
    }

    /// "YYYY-MM-DD" -> "M月d日" (パース不能ならそのまま返す)
    private func displayDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return date }
        return "\(m)月\(d)日"
    }

    /// 今日 (JST) の YYYY-MM-DD。予定日が今日かの判定に使う
    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: Date())
    }

    private var favoriteButton: some View {
        let kind = item.kindEnum
        let isFav = favoritesStore.isFavoriteRespectingSession(
            kind: kind,
            targetId: item.pool_id,
            fallback: item.is_favorite
        )
        return FavoriteToggleButton(isFavorite: isFav, size: 16, padding: 10) {
            Task {
                await favoritesStore.setFavorite(
                    !isFav,
                    kind: kind,
                    targetId: item.pool_id,
                    imageURL: item.image_url
                )
            }
        }
    }

    private var hasCoordItems: Bool {
        ["tops", "bottoms", "outer", "accessory"].contains { key in
            if let v = item.items[key] ?? nil, !v.isEmpty { return true }
            return false
        }
    }

    private var coordItemsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(["tops", "bottoms", "outer", "accessory"], id: \.self) { key in
                if let v = item.items[key] ?? nil, !v.isEmpty {
                    HStack(alignment: .top) {
                        Text(labelFor(key))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(v).font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
    }

    // 手持ちアイテムとの一致: このコーデを自分のクローゼットで作れるか、足りないものは何か
    private var closetMatchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if item.owned_items.isEmpty {
                // 空状態: 一致する手持ちが無い (クローゼット未登録・少ない場合を含む)。
                // 「足りません」の羅列だけにせず、登録すると判定できることを案内する
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                        Text("このコーデに合う手持ちアイテムは見つかりませんでした")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    Text("コーデを撮影するとアイテムが自動で登録され、手持ちで作れるかが分かるようになります。")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Haptic.impact(.soft)
                        openItemRegistration()
                    } label: {
                        Text("コーデを撮って登録する")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.white)
                            .overlay(Capsule().stroke(Color.black.opacity(0.2), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if item.missing_items.isEmpty && !item.owned_items.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                    Text("手持ちのアイテムで作れます")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            ForEach(item.owned_items, id: \.self) { owned in
                HStack(spacing: 10) {
                    KFImage(URL(string: owned.image_url))
                        .placeholder { Color.gray.opacity(0.15) }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    Text(owned.label)
                        .font(.system(size: 14))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("持っています")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.green)
                }
            }

            // 足りないアイテムは行タップで ZOZOTOWN 検索へ (TomorrowPickSection の買い足し行と同じ導線)
            ForEach(item.missing_items, id: \.self) { label in
                Button {
                    Haptic.selection()
                    if let url = ZOZOSearchURL.url(for: label) {
                        webLink = HomeWebLink(url: url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .strokeBorder(
                                Color.gray.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5])
                            )
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "tshirt")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.gray.opacity(0.5))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                            Text("足りません")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .semibold))
                            Text("探す")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(Capsule().stroke(Color.black.opacity(0.25), lineWidth: 1))
                        .clipShape(Capsule())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if !item.missing_items.isEmpty {
                Text("「探す」からZOZOTOWNの検索結果を開けます")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// コーデ撮影シートへ (撮影するとアイテムが自動登録される既存フロー)。
    /// この詳細シートを閉じてから、ホームの FirstTakePhoto シートを開く
    /// (カレンダー空状態と同じ導線。シート二重提示を避けるため少し遅延させる)
    private func openItemRegistration() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            tabViewModel.selectedTab = .home
            tabViewModel.shouldShowFirstTakePhotoOnHome = true
        }
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

    // 着用記録 (worn_coordinates への学習シグナル)。カレンダーには表示されないため、
    // 完了形のラベル + 「相棒が学習する」キャプションで押した結果を予測できるようにする
    @ViewBuilder
    private var wearButton: some View {
        if marked {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("相棒に伝えました。次の提案に活かします")
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
                VStack(spacing: 3) {
                    HStack {
                        if isMarking { ProgressView().tint(.black) }
                        Text(isMarking ? "送信中…" : "今日これを着た").font(.headline)
                    }
                    Text("相棒が覚えて、次のコーデ提案に活かします")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white)
                .foregroundColor(.black)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.2), lineWidth: 1))
                .cornerRadius(10)
            }
            .disabled(isMarking)
        }
    }
}

#Preview("通常 (ホーム/お気に入り)") {
    NavigationStack {
        DailyRecommendationDetailView(
            item: DailyRecommendationResponse.mock().recommendations[0],
            onWear: { _ in
                try? await Task.sleep(nanoseconds: 500_000_000)
                return true
            }
        )
        .environment(FavoritesStore(client: MockFavoriteClient()))
        .environment(MainTabViewModel())
    }
}

#Preview("予定コーデ (今日) - 削除+着用あり") {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    return NavigationStack {
        DailyRecommendationDetailView(
            item: DailyRecommendationResponse.mock().recommendations[0],
            onWear: { _ in true },
            plannedDate: formatter.string(from: Date()),
            onDeletePlanned: {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return true
            }
        )
        .environment(FavoritesStore(client: MockFavoriteClient()))
        .environment(MainTabViewModel())
    }
}

#Preview("予定コーデ (未来日) - 着用なし") {
    NavigationStack {
        DailyRecommendationDetailView(
            item: DailyRecommendationResponse.mock().recommendations[0],
            onWear: { _ in true },
            plannedDate: "2030-01-01",
            onDeletePlanned: { true }
        )
        .environment(FavoritesStore(client: MockFavoriteClient()))
        .environment(MainTabViewModel())
    }
}
