//
//  PartnerMannequinDesigns.swift
//  irodori
//
//  相棒画面ブラッシュアップ: 「パーソナライズド・マネキンコーデ提案 + 根拠(ルール)」の
//  画面デザイン3案比較 (トグル同居の1ファイル)。
//
//  対象ユーザー: コーデを決める変数が多すぎて服選びに抵抗がある人。
//  解決: 診断(ファッションタイプ/動物占い)・体型(骨格/身長)・記録から
//        「あなたの定数」を3つだけ導出し、毎日の提案を定数への当てはめに還元する。
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
    static let reasons = [
        "手持ちの6割を占めるベース2色でまとまり、",
        "骨格ストレートの得意な直線シルエットです。",
    ]
    static let reasonLines = [
        (rule: "配色の定数", body: "ベースのネイビー×白。差し色はローファーのブラウン1点だけ。"),
        (rule: "シルエットの定数", body: "上をコンパクトに、下はテーパードで縦のIラインに。"),
    ]
    static let weatherLine = "最高26° 晴れ。長袖シャツ1枚でちょうどいい日。"
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

// MARK: - 案A「今日の正解」— 即答型

/// 開いた瞬間に答えが1つだけある。題字が理由を語り、詳細はタップ展開。
/// 決めるまで最短3秒。変数はすべて畳んである。
private struct MannequinDesignA: View {
    @State private var showReasons = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    PartnerIconImage(size: 34)
                    Text("今日はこれでいこう")
                        .font(.system(size: 20, weight: .bold))
                }

                MannequinCard()

                // 題字がルールを語る (バッジは使わない)
                VStack(alignment: .leading, spacing: 6) {
                    Text(MannequinSandbox.headline)
                        .font(.system(size: 15, weight: .bold))
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
                            Text(MannequinSandbox.weatherLine)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
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

/// 相棒が定数を1つずつ確認しながらコーデを手渡す。
/// ルールが会話として耳に入る。毎朝の儀式になる。
private struct MannequinDesignB: View {
    @State private var step = 0

    private let bubbles = [
        "おはよう。今日の分も、あなたの型で組んでおいたよ。",
        "定数のおさらい: Iライン、ネイビー×白、きれいめ7:3。",
        "最高26°の晴れだから、長袖シャツ1枚でちょうどいい。",
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(bubbles.prefix(step + 1).enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .top, spacing: 10) {
                        if index == 0 {
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
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if step >= bubbles.count - 1 {
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
        .task {
            while step < bubbles.count - 1 {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step += 1 }
                Haptic.impact(.soft)
            }
        }
    }
}

// MARK: - 案C「あなたの型」— 教育型

/// 定数を常設で見せ、提案がその定数から導かれたことを紐づける。
/// 「ルールを知らない」に最直球。使うほどルールが身につく。
private struct MannequinDesignC: View {
    @State private var expandedConstant: String?

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
