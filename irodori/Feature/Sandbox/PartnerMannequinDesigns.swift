//
//  PartnerMannequinDesigns.swift
//  irodori
//
//  【不採用 2026-08-25】相棒画面ブラッシュアップ第1版: 画面デザイン3案比較。
//  「画面ごと差し替え」の構成が不採用となり、第2版 (PartnerMitateDesign.swift =
//  現行の相棒画面に「今日の見立て」セクションを追加 + マネキンは試着画像) に引き継いだ。
//  変数モデル・定数エンジンの設計は第2版でも有効。記録として残す。
//
//  対象ユーザー: コーデを決める変数が多すぎて服選びに抵抗がある人。
//  変数モデル: 決めるコスト = アウター×トップス×ボトムス×気温×天気×場所×人×時間×重複
//  (例 10*10*3*2*X*Y*3*Z)。この積を以下の4分類で畳み、最終的に「これでいく/別の一手」の
//  2択まで還元する:
//  - アイテム変数 (アウター/トップス/ボトムス) → 定数(型)でフィルタし提案1件に
//  - 環境変数 (気温/天気)                     → 相棒が自動観測 (×1)
//  - 文脈変数 (場所/人/時間)                  → 「いつもの一日」デフォルト+例外1タップ (ContextRow)
//  - 制約変数 (直近コーデとの重複)             → 着用記録から自動回避 (×1)
//  消した変数は黙って消さず「確認済み」と一言申告する (eliminatedLine)。
//  - 案A「今日の正解」   : 即答型。マネキン+題字1行。3秒で決められる
//  - 案B「相棒の朝礼」   : 対話型。相棒が定数を確認しながら手渡す
//  - 案C「あなたの型」   : 教育型。定数を常設表示し、提案と根拠を紐づける
//
//  デザイン原則 (アプリ全体の言語に統一):
//  - 白背景・モノトーン・余白主役。相棒画面の pink/グラデは使わない
//  - バッジ/チップ禁止 → 根拠は題字と色文字のタイポグラフィで語る (ReasonHeadline の思想)
//  - 相棒の存在感は PartnerIconImage と一言に集約
//

import SwiftUI

// MARK: - 共通モックデータ

enum MannequinSandbox {
    struct Constant: Identifiable {
        let id: String        // "silhouette" | "palette" | "balance"
        let title: String     // 定数名
        let value: String     // 値 (題字で使う)
        let derivation: String // 由来 (タップで表示)
    }

    struct OutfitPiece: Identifiable {
        let id: String
        let slot: String      // トップス / ボトムス / シューズ / 小物
        let name: String
        let color: Color
        let symbol: String    // SF Symbol
    }

    static let constants: [Constant] = [
        .init(id: "silhouette", title: "シルエット", value: "Iライン",
              derivation: "骨格タイプ (ストレート) と身長 160cm から。縦の直線がいちばん映える型です。"),
        .init(id: "palette", title: "配色", value: "ネイビー × 白 + 差し色ブラウン",
              derivation: "クローゼットの 6割 を占めるベース2色に、診断タイプの落ち着いた差し色を1つだけ足しています。"),
        .init(id: "balance", title: "バランス", value: "きれいめ 7 : カジュアル 3",
              derivation: "ファッションタイプ診断 (美学×定番) と直近の着用記録から導いた、あなたの黄金比です。"),
    ]

    static let outfit: [OutfitPiece] = [
        .init(id: "tops", slot: "トップス", name: "白 バンドカラーシャツ",
              color: Color(white: 0.97), symbol: "tshirt"),
        .init(id: "bottoms", slot: "ボトムス", name: "ネイビー テーパードパンツ",
              color: Color(red: 0.16, green: 0.20, blue: 0.32), symbol: "figure.walk"),
        .init(id: "shoes", slot: "シューズ", name: "ブラウン ローファー",
              color: Color(red: 0.42, green: 0.29, blue: 0.20), symbol: "shoe"),
    ]

    static let headline = "定数どおり、Iラインのネイビー×白。"
    static let reasonLines = [
        (rule: "配色の定数", body: "ベースのネイビー×白。差し色はローファーのブラウン1点だけ。"),
        (rule: "シルエットの定数", body: "上をコンパクトに、下はテーパードで縦のIラインに。"),
    ]

    // 文脈変数 (場所・人・時間) はデフォルト + 例外時のみ1タップに畳む
    static let contextDefault = "いつもの一日"
    static let contextOptions = ["いつもの一日", "しごと きっちりめ", "デート・おでかけ", "遠出・よく歩く"]

    // 消した変数の申告。環境変数 (気温・天気) と制約変数 (直近の重複) は
    // 相棒が確認済みであることを一言で伝える (黙って消すと信頼されない)
    static let eliminatedLine = "気温26°・晴れは確認済み。おととい着たシャツは外してあります。"
}

// MARK: - 共通部品: マネキン (置き画スタイルのプレースホルダ)

/// 本番は api/outfit-collage の合成画像 (collage_url) を表示する。
/// Sandbox では通信なしで構図を確認できるよう、スロットタイルで代替する。
private struct MannequinCard: View {
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            ForEach(MannequinSandbox.outfit) { piece in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(piece.color)
                        .frame(width: compact ? 44 : 56, height: compact ? 44 : 56)
                        .overlay(
                            Image(systemName: piece.symbol)
                                .font(.system(size: compact ? 16 : 20))
                                .foregroundStyle(piece.id == "tops" ? Color.gray.opacity(0.5) : .white.opacity(0.85)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(piece.slot)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(piece.name)
                            .font(.system(size: compact ? 12 : 14, weight: .medium))
                    }
                    Spacer()
                }
            }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - 共通部品: 文脈変数の1タップ切替

/// 場所・人・時間 (Y×3×Z 通り) を「いつもの一日」のデフォルトに畳み、
/// 例外の日だけ1タップで上書きする。入力コントロールなのでバッジ禁止の対象外。
private struct ContextRow: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            Text("きょうは")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Menu {
                ForEach(MannequinSandbox.contextOptions, id: \.self) { option in
                    Button(option) {
                        Haptic.selection()
                        selection = option
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .underline()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - 案A「今日の正解」— 即答型

/// 開いた瞬間に答えが1つだけある。題字が理由を語り、詳細はタップ展開。
/// 決めるまで最短3秒。変数はすべて畳んである。
private struct MannequinDesignA: View {
    @State private var showReasons = false
    @State private var context = MannequinSandbox.contextDefault

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    PartnerIconImage(size: 34)
                    Text("今日はこれでいこう")
                        .font(.system(size: 20, weight: .bold))
                }

                ContextRow(selection: $context)

                MannequinCard()

                // 題字がルールを語り、消した変数 (気温・天気・重複) は一言で申告する
                VStack(alignment: .leading, spacing: 6) {
                    Text(MannequinSandbox.headline)
                        .font(.system(size: 15, weight: .bold))
                    Text(MannequinSandbox.eliminatedLine)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showReasons.toggle()
                        }
                    } label: {
                        Text(showReasons ? "とじる" : "なぜこれ？")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    if showReasons {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(MannequinSandbox.reasonLines, id: \.rule) { line in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(line.rule)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.teal)
                                    Text(line.body)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                VStack(spacing: 8) {
                    Button {
                        Haptic.notify(.success)
                    } label: {
                        Text("これでいく")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    Button {
                        Haptic.impact(.soft)
                    } label: {
                        Text("型のまま、別の一手")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.gray.opacity(0.04))
    }
}

// MARK: - 案B「相棒の朝礼」— 対話型

/// 相棒が文脈変数 (場所・人・時間) を1問で畳み、定数を確認しながらコーデを手渡す。
/// ルールが会話として耳に入る。毎朝の儀式になる。
private struct MannequinDesignB: View {
    /// nil = 未回答。回答後に相棒の続きが流れる
    @State private var contextAnswer: String?
    @State private var step = 0

    private var bubbles: [String] {
        [
            "おはよう。きょうは、いつもの一日でいい？",
            contextAnswer == MannequinSandbox.contextDefault
                ? "OK。じゃあ定数のおさらい: Iライン、ネイビー×白、きれいめ7:3。"
                : "了解、\(contextAnswer ?? "")向けにきれいめを1段上げるね。定数は Iライン、ネイビー×白。",
            MannequinSandbox.eliminatedLine,
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                partnerBubble(bubbles[0], showIcon: true)

                if let contextAnswer {
                    // ユーザーの返答 (右寄せ・黒)
                    HStack {
                        Spacer(minLength: 60)
                        Text(contextAnswer)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                    ForEach(1...max(1, min(step, bubbles.count - 1)), id: \.self) { index in
                        partnerBubble(bubbles[index], showIcon: false)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                } else {
                    // 返答チップ: 文脈変数 (Y×3×Z通り) をここで2タップ以内に畳む
                    HStack(spacing: 8) {
                        Spacer(minLength: 40)
                        replyChip(MannequinSandbox.contextDefault)
                        Menu {
                            ForEach(MannequinSandbox.contextOptions.dropFirst(), id: \.self) { option in
                                Button(option) { answer(option) }
                            }
                        } label: {
                            Text("予定がある日")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.gray.opacity(0.35), lineWidth: 1))
                        }
                    }
                }

                if contextAnswer != nil && step >= bubbles.count - 1 {
                    MannequinCard(compact: true)
                        .padding(.leading, 46)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))

                    HStack(alignment: .top, spacing: 10) {
                        Color.clear.frame(width: 36, height: 1)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MannequinSandbox.headline)
                                .font(.system(size: 14, weight: .bold))
                            ForEach(MannequinSandbox.reasonLines, id: \.rule) { line in
                                Text(line.body)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        Spacer(minLength: 24)
                    }
                    .transition(.opacity)

                    HStack(spacing: 8) {
                        Button {
                            Haptic.notify(.success)
                        } label: {
                            Text("これでいく")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        Button {
                            Haptic.impact(.soft)
                        } label: {
                            Text("別の一手")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 110)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 46)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.gray.opacity(0.04))
        // 返答後に相棒の続き (定数おさらい → 消し込み申告) を流す
        .task(id: contextAnswer) {
            guard contextAnswer != nil else { return }
            while step < bubbles.count - 1 {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step += 1 }
                Haptic.impact(.soft)
            }
        }
    }

    private func answer(_ option: String) {
        Haptic.selection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            contextAnswer = option
            step = 1
        }
    }

    private func partnerBubble(_ text: String, showIcon: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if showIcon {
                PartnerIconImage(size: 36)
            } else {
                Color.clear.frame(width: 36, height: 1)
            }
            Text(text)
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 24)
        }
    }

    private func replyChip(_ option: String) -> some View {
        Button {
            answer(option)
        } label: {
            Text(option)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.black)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 案C「あなたの型」— 教育型

/// 定数を常設で見せ、提案がその定数から導かれたことを紐づける。
/// 「ルールを知らない」に最直球。使うほどルールが身につく。
private struct MannequinDesignC: View {
    @State private var expandedConstant: String?
    @State private var context = MannequinSandbox.contextDefault

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // ── あなたの定数 (常設) ──
                VStack(alignment: .leading, spacing: 2) {
                    Text("あなたの定数")
                        .font(.system(size: 20, weight: .bold))
                    Text("診断と記録から導いた、迷わないための3つのルール")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(MannequinSandbox.constants) { constant in
                        ConstantRow(
                            constant: constant,
                            isExpanded: expandedConstant == constant.id,
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    expandedConstant = expandedConstant == constant.id ? nil : constant.id
                                }
                            })
                        if constant.id != MannequinSandbox.constants.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.07), lineWidth: 1))

                // ── 型から、今日の一着 ──
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        PartnerIconImage(size: 28)
                        Text("型から、今日の一着")
                            .font(.system(size: 16, weight: .bold))
                    }
                    ContextRow(selection: $context)
                    MannequinCard(compact: true)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(MannequinSandbox.reasonLines, id: \.rule) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(line.rule)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.teal)
                                    .frame(width: 96, alignment: .leading)
                                Text(line.body)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(MannequinSandbox.eliminatedLine)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Haptic.notify(.success)
                    } label: {
                        Text("これでいく")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.gray.opacity(0.04))
    }
}

// 定数1行 (案C用)。式が深くなり型チェックが重くなるため部品に分離している
private struct ConstantRow: View {
    let constant: MannequinSandbox.Constant
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onTap) {
                HStack(alignment: .firstTextBaseline) {
                    Text(constant.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 76, alignment: .leading)
                    Text(constant.value)
                        .font(.system(size: 15, weight: .bold))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                Text(constant.derivation)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.leading, 76)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - 比較ビュー

struct PartnerMannequinDesignsCompare: View {
    @State private var selected = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("案", selection: $selected) {
                Text("A 今日の正解").tag(0)
                Text("B 朝礼").tag(1)
                Text("C あなたの型").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            switch selected {
            case 0: MannequinDesignA().id(0)
            case 1: MannequinDesignB().id(1)
            default: MannequinDesignC().id(2)
            }
        }
    }
}

#Preview("3案 比較") {
    PartnerMannequinDesignsCompare()
}

#Preview("A 今日の正解") { MannequinDesignA() }
#Preview("B 相棒の朝礼") { MannequinDesignB() }
#Preview("C あなたの型") { MannequinDesignC() }
