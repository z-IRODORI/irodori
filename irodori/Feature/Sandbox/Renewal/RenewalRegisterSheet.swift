//
//  RenewalRegisterSheet.swift
//  irodori - Sandbox
//
//  「＋ 登録」ハーフシート (app_ecosystem_and_improvement_design.md §2)
//   ① 写真フォルダから AI 自動発掘 (onboarding_ai_picker_design.md: 期間・枚数の設定なし / 上位5枚を選択済み / 複数枚を一括解析)
//   ② 定番タップ ＆ キーワード検索 (撮影不要)
//   ③ カメラで全身1枚 (カレンダー記録 + アイテム分解を同時に)
//  選んだ直後にシートを閉じ、解析は裏で進めてトーストで報告する (待ち時間ゼロ)。
//
//  ※ Sandbox では写真ライブラリ・カメラにはアクセスせず、サンプルの全身写真 (色のシルエット) で再現する。
//

import SwiftUI

enum RenewalRegisterMethod: Hashable {
    case photo, staple, camera
}

struct RenewalRegisterSheet: View {
    let store: RenewalStore
    var initialMethod: RenewalRegisterMethod?

    @Environment(\.dismiss) private var dismiss
    @State private var path: [RenewalRegisterMethod] = []
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    RenewalPartnerAvatar(typeName: store.typeName, size: 32)
                    Text("どの方法で教えてくれる？いまやりやすいものでOKだよ。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RenewalTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 0) {
                    methodRow(.photo, icon: "photo.on.rectangle.angled", title: "写真フォルダから自動で見つける",
                              sub: "初回・まとめて登録に。過去の全身写真から服とコーデを一括で")
                    Divider().overlay(RenewalTokens.rule)
                    methodRow(.staple, icon: "magnifyingglass", title: "定番から選ぶ・検索する",
                              sub: "夜や写真がない時に。撮影なしでタップして追加")
                    Divider().overlay(RenewalTokens.rule)
                    methodRow(.camera, icon: "camera", title: "カメラで全身を1枚撮る",
                              sub: "お出かけ前の5秒で。今日の記録と服の登録が同時に完了")
                }
                .renewalCard()
                Spacer(minLength: 0)
            }
            .padding(RenewalTokens.edge)
            .background(RenewalTokens.ground)
            .navigationTitle("登録")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: RenewalRegisterMethod.self) { method in
                switch method {
                case .photo: RenewalPhotoFinderView(store: store) { dismiss() }
                case .staple: RenewalStaplePickerView(store: store) { dismiss() }
                case .camera: RenewalCameraSnapView(store: store) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onChange(of: path) { detent = path.isEmpty ? .medium : .large }
        .onAppear {
            if let initialMethod {
                path = [initialMethod]
                detent = .large
            }
        }
    }

    private func methodRow(_ method: RenewalRegisterMethod, icon: String, title: String, sub: String) -> some View {
        Button {
            Haptic.impact(.soft)
            path.append(method)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(RenewalTokens.ink)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(RenewalTokens.ink)
                    Text(sub).font(.system(size: 12)).foregroundStyle(RenewalTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ① 写真フォルダから AI 自動発掘

struct RenewalPhotoFinderView: View {
    let store: RenewalStore
    var onDone: () -> Void

    private enum Step { case face, scanning, result }

    @State private var step: Step = .face
    @State private var revealed = 0
    @State private var selected: Set<Int> = []
    @State private var murmur = "あなたの写真を探しているよ"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var candidates: [RenewalStore.PhotoCandidate] { store.photoCandidates() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch step {
                case .face: faceStep
                case .scanning: scanningStep
                case .result: resultStep
                }
            }
            .padding(RenewalTokens.edge)
        }
        .background(RenewalTokens.ground)
        .navigationTitle("写真フォルダから見つける")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if step == .result {
                Button("この\(selected.count)枚ではじめる") {
                    let photos = candidates.filter { selected.contains($0.id) }
                    store.importPhotos(photos)
                    onDone()
                }
                .buttonStyle(RenewalPrimaryButtonStyle())
                .disabled(selected.isEmpty)
                .padding(.horizontal, RenewalTokens.edge)
                .padding(.vertical, 10)
                .background(RenewalTokens.surface)
            }
        }
    }

    // 顔写真を1枚選ぶだけ (期間・枚数の設定は出さない。直近1年・最大500枚で固定)
    private var faceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("自分の顔がわかる写真を1枚選ぶだけ。あとは相棒が、写真フォルダからあなたの全身コーデを探します。")
                .font(.system(size: 14))
                .foregroundStyle(RenewalTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("直近1年・最大500枚を自動でスキャン (約15秒)")
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.muted)
            Image(systemName: "person.crop.square")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(RenewalTokens.muted)
                .frame(maxWidth: .infinity, minHeight: 160)
                .renewalCard()
                .accessibilityHidden(true)
            Button("サンプルの顔写真で探す") { startScan() }
                .buttonStyle(RenewalPrimaryButtonStyle())
            Text("Sandbox では写真ライブラリにアクセスせず、サンプルの全身写真で再現します。")
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
        }
    }

    private func startScan() {
        Haptic.impact(.soft)
        step = .scanning
        Task { @MainActor in
            let murmurs = ["あ、いいコーデ見つけた", "この日の服も素敵だね", "よく着ている服が見えてきたよ", "もう少しで終わるよ"]
            for i in 0..<candidates.count {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 420))
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) { revealed = i + 1 }
                if i % 2 == 1 { murmur = murmurs[(i / 2) % murmurs.count] }
            }
            try? await Task.sleep(for: .milliseconds(400))
            // 上位5枚を最初から選択済みに
            selected = Set(candidates.sorted { $0.score > $1.score }.prefix(5).map(\.id))
            Haptic.notify(.success)
            withAnimation { step = .result }
        }
    }

    // スキャン中: 見つけた写真がポラロイドのように浮かび上がる
    private var scanningStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RenewalPartnerAvatar(typeName: store.typeName, size: 32)
                Text(murmur)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .contentTransition(.opacity)
                Spacer()
                ProgressView()
            }
            .accessibilityElement(children: .combine)
            grid(showSelection: false)
        }
    }

    private var resultStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(candidates.count)枚の全身写真が見つかったよ。この5枚のコーデから好みを学習するね。外したい写真だけタップしてね。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RenewalTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            grid(showSelection: true)
        }
    }

    private func grid(showSelection: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(candidates.prefix(showSelection ? candidates.count : revealed)) { photo in
                let isOn = selected.contains(photo.id)
                Button {
                    guard showSelection else { return }
                    Haptic.selection()
                    if isOn { selected.remove(photo.id) } else { selected.insert(photo.id) }
                } label: {
                    VStack(spacing: 6) {
                        RenewalExampleImage(
                            recipe: RenewalRecipe(ownedItems: [], missingItems: photo.staples, kind: .zero, heroID: nil, mainFamily: photo.staples[0].family),
                            height: 170
                        )
                        Text(store.dateLabel(store.state.today - photo.daysAgo))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                    .padding(6)
                    .background(RenewalTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(showSelection && isOn ? RenewalTokens.ink : RenewalTokens.border, lineWidth: showSelection && isOn ? 2 : 1))
                    .overlay(alignment: .topTrailing) {
                        if showSelection {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(isOn ? RenewalTokens.ink : RenewalTokens.controlBorder)
                                .background(Circle().fill(.white))
                                .padding(10)
                        }
                    }
                    .rotationEffect(.degrees(showSelection || reduceMotion ? 0 : Double((photo.id % 3) - 1) * 2))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(store.dateLabel(store.state.today - photo.daysAgo))の全身写真")
                .accessibilityAddTraits(showSelection && isOn ? .isSelected : [])
            }
        }
    }
}

// MARK: - ② 定番から選ぶ・検索する

struct RenewalStaplePickerView: View {
    let store: RenewalStore
    var onDone: () -> Void

    @State private var query = ""
    @State private var picked: Set<String> = []

    private var filtered: [RenewalStaple] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return RenewalStaple.catalog }
        return RenewalStaple.catalog.filter { $0.name.contains(q) || $0.category.label.contains(q) || $0.family.label.contains(q) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("持っている服をタップしてね。完全に同じでなくても、近ければOK。")
                    .font(.system(size: 14))
                    .foregroundStyle(RenewalTokens.ink)
                ForEach(RenewalCategory.allCases) { category in
                    let items = filtered.filter { $0.category == category }
                    if !items.isEmpty {
                        Text(category.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RenewalTokens.muted)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                            ForEach(items) { staple in
                                tile(staple)
                            }
                        }
                    }
                }
            }
            .padding(RenewalTokens.edge)
        }
        .background(RenewalTokens.ground)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "例: 黒 / スラックス / ニット")
        .navigationTitle("定番から選ぶ")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(picked.isEmpty ? "持っている服を選んでね" : "\(picked.count)着をクローゼットに追加") {
                let staples = picked.compactMap { RenewalStaple.find($0) }
                store.addItems(staples, source: .staple)
                onDone()
            }
            .buttonStyle(RenewalPrimaryButtonStyle())
            .disabled(picked.isEmpty)
            .opacity(picked.isEmpty ? 0.5 : 1)
            .padding(.horizontal, RenewalTokens.edge)
            .padding(.vertical, 10)
            .background(RenewalTokens.surface)
        }
    }

    private func tile(_ staple: RenewalStaple) -> some View {
        let already = store.owns(staple)
        let isOn = picked.contains(staple.id)
        return Button {
            guard !already else { return }
            Haptic.selection()
            if isOn { picked.remove(staple.id) } else { picked.insert(staple.id) }
        } label: {
            RenewalItemTile(staple: staple, size: 64, owned: true)
                .overlay(alignment: .topTrailing) {
                    if already || isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(already ? RenewalTokens.muted : RenewalTokens.ink)
                            .background(Circle().fill(.white))
                            .offset(x: -2, y: 2)
                    }
                }
                .opacity(already ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(staple.name)
        .accessibilityValue(already ? "登録済み" : (isOn ? "選択中" : "未選択"))
    }
}

// MARK: - ③ カメラで全身を1枚

struct RenewalCameraSnapView: View {
    let store: RenewalStore
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: RenewalTokens.cardRadius)
                    .fill(Color.black.opacity(0.88))
                Image(systemName: "figure.stand")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.5))
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .padding(40)
                VStack {
                    Spacer()
                    Text("全身が枠に入るように")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.bottom, 14)
                }
            }
            .frame(maxHeight: 420)
            .accessibilityHidden(true)

            Text("1枚撮るだけで、今日のカレンダー記録と、着ている服のクローゼット登録が同時に終わります。")
                .font(.system(size: 13))
                .foregroundStyle(RenewalTokens.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.cameraSnapshot()
                onDone()
            } label: {
                Label("撮影する (サンプル)", systemImage: "camera.fill")
            }
            .buttonStyle(RenewalPrimaryButtonStyle())
        }
        .padding(RenewalTokens.edge)
        .background(RenewalTokens.ground)
        .navigationTitle("カメラで全身を撮る")
        .navigationBarTitleDisplayMode(.inline)
    }
}
