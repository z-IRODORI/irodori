//
//  RenewalPartnerView.swift
//  irodori - Sandbox
//
//  相棒画面 = 「わたしの理解カルテ」(app_ecosystem §4・§5④ / partner_action_stock §4・§5)
//   1. 相棒ヘッダー (話し方チップ・チャット相談)
//   2. 相棒が理解しているあなたのこと (3行スタイル定義 + 4問 + 行動から見つけた傾向)
//   3. 相棒からのアドバイス (いまの強み / 次の発見)
//   4. 相棒にもっと教える (写真 / アイテム検索 / 2択比較 / 4問の回答変更)
//   5. 相棒が新しく覚えたこと (行動 → 学んだ1行メモ)
//  円形ゲージ・Lv・EXP・絵文字ボタンは置かない。
//

import SwiftUI

struct RenewalPartnerView: View {
    let store: RenewalStore
    var onOpenRegister: (RenewalRegisterMethod) -> Void

    @State private var showToneSheet = false
    @State private var showTasteVote = false
    @State private var showEditAnswers = false
    @State private var showChatNote = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                styleDefinition
                carte
                advice
                teachMenu
                timeline
            }
            .padding(.horizontal, RenewalTokens.edge)
            .padding(.vertical, 16)
        }
        .background(RenewalTokens.ground)
        .navigationTitle("相棒")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showToneSheet) {
            RenewalToneSheet(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTasteVote) {
            RenewalTasteVoteSheet(store: store)
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showEditAnswers) {
            NavigationStack {
                RenewalOnboardingView(store: store, mode: .edit) { showEditAnswers = false }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("閉じる") { showEditAnswers = false }
                                .foregroundStyle(RenewalTokens.ink)
                        }
                    }
            }
        }
        .alert("チャットで相談 (Sandbox では省略)", isPresented: $showChatNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("本番では既存の相棒チャットを開き、理解カルテを前提に相談できます。")
        }
    }

    // MARK: - 1. ヘッダー

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            RenewalPartnerAvatar(typeName: store.typeName, size: 64)
            VStack(alignment: .leading, spacing: 8) {
                Text(store.typeName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                HStack(spacing: 8) {
                    Button {
                        showToneSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("話し方: \(store.tone.label)")
                            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                        .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius).stroke(RenewalTokens.controlBorder, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("話し方を変更します")

                    Button {
                        showChatNote = true
                    } label: {
                        Text("チャットで相談")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius).stroke(RenewalTokens.controlBorder, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 2. 理解カルテ

    private var styleDefinition: some View {
        VStack(alignment: .leading, spacing: 10) {
            RenewalSectionTitle(title: "あなたのスタイル定義", caption: "服や着用記録が増えるほど、相棒が書き換えていきます")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(store.styleDefinition.enumerated()), id: \.element.id) { i, row in
                    if i > 0 { Divider().overlay(RenewalTokens.rule) }
                    carteRow(row)
                }
            }
            .renewalCard()
        }
    }

    private var carte: some View {
        VStack(alignment: .leading, spacing: 10) {
            RenewalSectionTitle(title: "相棒が理解しているあなたのこと", caption: "4問の回答 ＋ 行動から見つけた傾向")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(store.carteRows.enumerated()), id: \.element.id) { i, row in
                    if i > 0 { Divider().overlay(RenewalTokens.rule) }
                    carteRow(row)
                }
            }
            .renewalCard()
        }
    }

    private func carteRow(_ row: RenewalStore.CarteRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(row.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RenewalTokens.muted)
                .frame(width: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(row.value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if row.learned { RenewalLearnedTag() }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 3. アドバイス

    @ViewBuilder
    private var advice: some View {
        VStack(alignment: .leading, spacing: 10) {
            RenewalSectionTitle(title: "相棒からのアドバイス")
            if let advice = store.advice {
                VStack(alignment: .leading, spacing: 0) {
                    adviceRow("いまの強み", advice.strength)
                    Divider().overlay(RenewalTokens.rule)
                    adviceRow("次の発見", advice.next)
                }
                .renewalCard()
            } else {
                Text("手持ちの服を2着以上教えてくれたら、着回しの強みと次の一手を伝えるね。")
                    .font(.system(size: 13))
                    .foregroundStyle(RenewalTokens.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .renewalCard()
            }
        }
    }

    private func adviceRow(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RenewalTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 4. 相棒にもっと教える

    private var teachMenu: some View {
        VStack(alignment: .leading, spacing: 10) {
            RenewalSectionTitle(title: "相棒にもっと教える", caption: "教えるほど、手持ち服を使った提案が具体的になります")
            VStack(spacing: 0) {
                teachRow("photo", "写真フォルダから自動で見つける", "過去の全身写真から、服とコーデをまとめて登録") { onOpenRegister(.photo) }
                Divider().overlay(RenewalTokens.rule)
                teachRow("magnifyingglass", "アイテムを検索・定番から選ぶ", "撮影なし。持っている服をタップで追加") { onOpenRegister(.staple) }
                Divider().overlay(RenewalTokens.rule)
                teachRow("square.split.2x1", "2つのコーデを見比べる", "直感で選ぶだけ。配色やシルエットの好みを共有") { showTasteVote = true }
                Divider().overlay(RenewalTokens.rule)
                teachRow("arrow.triangle.2.circlepath", "4問の回答を変更する", "なりたい印象・感覚・提案の幅・話し方") { showEditAnswers = true }
            }
            .renewalCard()
        }
    }

    private func teachRow(_ icon: String, _ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(RenewalTokens.ink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(RenewalTokens.ink)
                    Text(sub).font(.system(size: 12)).foregroundStyle(RenewalTokens.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. 相棒が新しく覚えたこと

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            RenewalSectionTitle(title: "相棒が新しく覚えたこと")
            if store.state.logs.isEmpty {
                Text("まだ記録はありません")
                    .font(.system(size: 13))
                    .foregroundStyle(RenewalTokens.muted)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(store.state.logs.reversed().prefix(20).enumerated()), id: \.element.id) { i, log in
                        if i > 0 { Divider().overlay(RenewalTokens.rule) }
                        HStack(alignment: .top, spacing: 12) {
                            Text(store.dateLabel(log.day))
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundStyle(RenewalTokens.muted)
                                .frame(width: 58, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(log.action)
                                    .font(.system(size: 12))
                                    .foregroundStyle(RenewalTokens.muted)
                                Text("→ \(log.learned)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(RenewalTokens.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                    }
                }
                .renewalCard()
            }
        }
    }
}

// MARK: - 話し方の変更シート (例文プレビュー付き)

struct RenewalToneSheet: View {
    let store: RenewalStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: RenewalTone = .gentle

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Text("同じ朝のひとことでも、話し方でこう変わります。変えた瞬間にホームの言葉も切り替わります。")
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(RenewalTone.allCases) { tone in
                        Button {
                            Haptic.selection()
                            selected = tone
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(tone.label).font(.system(size: 14, weight: .semibold))
                                    if tone == store.tone {
                                        Text("いまの話し方")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(RenewalTokens.muted)
                                    }
                                    Spacer()
                                    Image(systemName: selected == tone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected == tone ? RenewalTokens.ink : RenewalTokens.controlBorder)
                                }
                                Text(tone.character)
                                    .font(.system(size: 12))
                                    .foregroundStyle(RenewalTokens.muted)
                                Text("「\(RenewalCopy.tonePreview(tone))」")
                                    .font(.system(size: 13))
                                    .foregroundStyle(RenewalTokens.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RenewalTokens.raised)
                                    .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius))
                            }
                            .foregroundStyle(RenewalTokens.ink)
                            .padding(14)
                            .background(RenewalTokens.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
                            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius)
                                .stroke(selected == tone ? RenewalTokens.ink : RenewalTokens.border, lineWidth: selected == tone ? 1.5 : 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == tone ? .isSelected : [])
                    }
                }
                .padding(RenewalTokens.edge)
            }
            .background(RenewalTokens.ground)
            .safeAreaInset(edge: .bottom) {
                Button("この話し方にする") {
                    store.changeTone(selected)
                    dismiss()
                }
                .buttonStyle(RenewalPrimaryButtonStyle())
                .disabled(selected == store.tone)
                .opacity(selected == store.tone ? 0.5 : 1)
                .padding(.horizontal, RenewalTokens.edge)
                .padding(.vertical, 10)
                .background(RenewalTokens.surface)
            }
            .navigationTitle("話し方を変える")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.foregroundStyle(RenewalTokens.ink)
                }
            }
            .onAppear { selected = store.tone }
        }
    }
}

// MARK: - 2択比較 (3回)

struct RenewalTasteVoteSheet: View {
    let store: RenewalStore
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var picks: [RenewalColorFamily] = []

    private let pairs: [(RenewalColorFamily, RenewalColorFamily)] = [(.mono, .earth), (.navy, .accent), (.denim, .mono)]

    private func sample(_ family: RenewalColorFamily) -> RenewalRecipe {
        let top = RenewalStaple.catalog.first { $0.category == .top && $0.family == family } ?? RenewalStaple.catalog[0]
        let bottom = RenewalStaple.catalog.first { $0.category == .bottom && $0.family == family } ?? RenewalStaple.catalog[8]
        let shoes = RenewalStaple.catalog.first { $0.category == .shoes && $0.family == family } ?? RenewalStaple.catalog[19]
        return RenewalRecipe(ownedItems: [], missingItems: [top, bottom, shoes], kind: .zero, heroID: nil, mainFamily: family)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("直感で、気になる方をタップしてね (\(min(index + 1, pairs.count))/\(pairs.count))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                if index < pairs.count {
                    HStack(spacing: 12) {
                        option(pairs[index].0)
                        option(pairs[index].1)
                    }
                }
                Spacer()
            }
            .padding(RenewalTokens.edge)
            .background(RenewalTokens.ground)
            .navigationTitle("2つのコーデを見比べる")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.foregroundStyle(RenewalTokens.ink)
                }
            }
        }
    }

    private func option(_ family: RenewalColorFamily) -> some View {
        Button {
            Haptic.selection()
            picks.append(family)
            if index + 1 >= pairs.count {
                store.recordTasteVote(picks)
                dismiss()
            } else {
                index += 1
            }
        } label: {
            VStack(spacing: 8) {
                RenewalExampleImage(recipe: sample(family), height: 260)
                Text(family.vibe)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .renewalCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(family.vibe)
    }
}
