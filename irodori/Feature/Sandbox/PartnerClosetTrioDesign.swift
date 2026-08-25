//
//  PartnerClosetTrioDesign.swift
//  irodori
//
//  相棒画面ブラッシュアップ第3版: 「クローゼットから、今日の3案」。
//  - 第1版 (PartnerMannequinDesigns.swift): 画面ごと差し替え型3案 → 不採用
//  - 第2版 (PartnerMitateDesign.swift): 試着画像マネキン1件のセクション → 不採用
//  - 第3版 (本ファイル): **既存の相棒画面の最上部に、クローゼット発のコーデ3件を
//    カルーセル表示** + 選択中の案に同期する丁寧な根拠。
//
//  3案の作り方 (本番実装時):
//  - 3案 = 日付由来の seed で POST /api/outfit-collage を3回 (Pillow合成のみ・LLM課金ゼロ)。
//    2案目以降は前案の tops/bottoms を exclude_item_ids に渡して重複を防ぐ
//  - 3案は「ただのシャッフル」ではなく役割を持つ:
//    ①いつもの正解 (定数ど真ん中) ②気分を変える一手 (差し色/シルエット変化) ③ラクな日の型 (カジュアル寄せ)
//  - 日付でキャッシュし、その日の3案は固定 (毎回変わると「決める」体験が壊れる)
//
//  根拠 (判断根拠を分かりやすく丁寧に):
//  - カルーセルの選択に同期して「相棒はこう考えました」カードが切り替わる
//  - 番号 = 実際の選定順 (1 天気をみる → 2 かぶりを消す → 3 あなたの定数にあてはめる)。
//    1・2 は3案共通、3 が案ごとの違いを説明する
//  - 変数モデル維持: 文脈は「きょうは▾」1タップ、消した変数は文中で申告
//

import SwiftUI

// MARK: - モックデータ

enum TrioSandbox {
    struct Piece: Hashable {
        let name: String
        let color: Color
        let symbol: String
    }

    struct Proposal: Identifiable {
        let id: String
        let role: String          // 案の役割 (題字)
        let headline: String      // この案のひとこと
        let pieces: [Piece]
        let constantSentence: String  // 根拠ステップ3 (案ごとに違う)
    }

    static let proposals: [Proposal] = [
        .init(
            id: "p1",
            role: "いつもの正解",
            headline: "定数どおり、Iラインのネイビー×白。",
            pieces: [
                .init(name: "白 バンドカラーシャツ", color: Color(white: 0.97), symbol: "tshirt"),
                .init(name: "ネイビー テーパード", color: Color(red: 0.16, green: 0.20, blue: 0.32), symbol: "figure.walk"),
                .init(name: "ブラウン ローファー", color: Color(red: 0.42, green: 0.29, blue: 0.20), symbol: "shoe"),
            ],
            constantSentence: "手持ちの6割を占めるネイビー×白をベースに、骨格ストレートさんが得意な縦のIラインでまとめました。迷ったらこれです。"),
        .init(
            id: "p2",
            role: "気分を変える一手",
            headline: "差し色のブラウンを、上に持ってくる日。",
            pieces: [
                .init(name: "ブラウン ニットベスト", color: Color(red: 0.45, green: 0.32, blue: 0.22), symbol: "tshirt"),
                .init(name: "白 ロングスカート", color: Color(white: 0.95), symbol: "figure.walk"),
                .init(name: "白 スニーカー", color: Color(white: 0.92), symbol: "shoe"),
            ],
            constantSentence: "定数の差し色ブラウンを小物ではなくトップスに。配色はあなたの3色の中なので、冒険して見えて外しません。"),
        .init(
            id: "p3",
            role: "ラクな日の型",
            headline: "黄金比をくずさず、いちばん身軽に。",
            pieces: [
                .init(name: "グレー スウェット", color: Color(white: 0.75), symbol: "tshirt"),
                .init(name: "ネイビー ワイド", color: Color(red: 0.18, green: 0.22, blue: 0.34), symbol: "figure.walk"),
                .init(name: "白 スニーカー", color: Color(white: 0.92), symbol: "shoe"),
            ],
            constantSentence: "きれいめ7:3の「3」の日用。カジュアルに寄せてもボトムスをネイビーに固定してあるので、だらしなく見えません。"),
    ]

    // 根拠ステップ1・2 は3案共通 (環境変数・制約変数の消し込み申告)
    static let commonSteps: [(number: String, label: String, sentence: String)] = [
        ("1", "天気をみる",
         "最高26°の晴れ。日中は暑くなるので、長袖1枚でちょうどいい日です。"),
        ("2", "かぶりを消す",
         "おととい着た白シャツと、きのうのデニムは3案とも外してあります。"),
    ]

    static let contextOptions = ["いつもの一日", "しごと きっちりめ", "デート・おでかけ", "遠出・よく歩く"]
}

// MARK: - コーデカード (カルーセル1枚)

private struct TrioProposalCard: View {
    let proposal: TrioSandbox.Proposal
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 案の役割が題字 (バッジではなくタイポグラフィで)
            Text(proposal.role)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(proposal.id == "p2" ? Color.teal : .black)

            // 本番はコラージュ画像 (collage_url)。Sandbox はスロットタイルで代替
            VStack(spacing: 7) {
                ForEach(proposal.pieces, id: \.self) { piece in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(piece.color)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: piece.symbol)
                                    .font(.system(size: 14))
                                    .foregroundStyle(piece.color == Color(white: 0.97) || piece.color == Color(white: 0.95) || piece.color == Color(white: 0.92)
                                                     ? Color.gray.opacity(0.5) : .white.opacity(0.85)))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.08), lineWidth: 1))
                        Text(piece.name)
                            .font(.system(size: 11.5, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 236, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.black : Color.black.opacity(0.07),
                        lineWidth: isSelected ? 1.5 : 1))
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 「クローゼットから、今日の3案」セクション

struct PartnerClosetTrioSection: View {
    @State private var currentID: String? = TrioSandbox.proposals.first?.id
    @State private var context = TrioSandbox.contextOptions[0]

    private var selected: TrioSandbox.Proposal {
        TrioSandbox.proposals.first { $0.id == currentID } ?? TrioSandbox.proposals[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            // ── 3案カルーセル ──
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(TrioSandbox.proposals) { proposal in
                        TrioProposalCard(proposal: proposal, isSelected: proposal.id == currentID)
                            .id(proposal.id)
                            .onTapGesture {
                                Haptic.selection()
                                withAnimation { currentID = proposal.id }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentID)
            .padding(.horizontal, -20)
            .contentMargins(.horizontal, 20, for: .scrollContent)

            // ── 選択中の案のひとこと (題字) ──
            Text(selected.headline)
                .font(.system(size: 15, weight: .bold))
                .id("headline-\(selected.id)")
                .transition(.opacity)

            // ── 相棒はこう考えました (選択に同期する丁寧な根拠) ──
            reasoningCard

            // ── CTA (ホームのカードと同じ並び: 試着 + これでいく) ──
            HStack(spacing: 8) {
                Button {
                    Haptic.impact(.soft)
                } label: {
                    Label("試着", systemImage: "person.crop.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 88)
                        .padding(.vertical, 11)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button {
                    Haptic.notify(.success)
                } label: {
                    Text("これでいく")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentID)
    }

    private var header: some View {
        HStack(spacing: 8) {
            PartnerIconImage(size: 28)
            Text("クローゼットから、今日の3案")
                .font(.system(size: 16, weight: .bold))
            Spacer()
            Menu {
                ForEach(TrioSandbox.contextOptions, id: \.self) { option in
                    Button(option) {
                        Haptic.selection()
                        context = option
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(context)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var reasoningCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("相棒はこう考えました")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)
            ForEach(Array(TrioSandbox.commonSteps.enumerated()), id: \.offset) { _, step in
                TrioReasoningRow(number: step.number, label: step.label, sentence: step.sentence)
                stepConnector
            }
            TrioReasoningRow(
                number: "3",
                label: "あなたの定数にあてはめる",
                sentence: selected.constantSentence)
            .id("step3-\(selected.id)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.07), lineWidth: 1))
    }

    private var stepConnector: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(width: 1.5, height: 10)
            .padding(.leading, 10)
    }
}

/// 根拠1ステップ: 番号 + 見出し + 完全な文章。番号は実際の選定順を表す。
private struct TrioReasoningRow: View {
    let number: String
    let label: String
    let sentence: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.black))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                Text(sentence)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - 現行の相棒画面に組み込んだ形 (配置確認用レプリカ)

struct PartnerClosetTrioInContext: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("相棒")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                // ★ 新設: 画面最上部にクローゼット3案
                PartnerClosetTrioSection()

                // 既存セクションの位置関係を示す簡易レプリカ
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 5)
                            .frame(width: 64, height: 64)
                        Circle()
                            .trim(from: 0, to: 0.42)
                            .stroke(Color.pink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 64, height: 64)
                        PartnerIconImage(size: 44)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lv.5 なかよし")
                            .font(.system(size: 14, weight: .bold))
                        Text("理解度 42% ・ 12日連続")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                PartnerTalkBubble(text: "きょうの3案、どれもクローゼットにある服だけで組んであるよ。")

                VStack(alignment: .leading, spacing: 6) {
                    Text("相棒からあなたへ")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("(既存のアドバイスカードがここに続く)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 28)
                        .background(Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
}

#Preview("相棒画面に組み込み") {
    PartnerClosetTrioInContext()
}

#Preview("セクション単体") {
    ScrollView {
        PartnerClosetTrioSection()
            .padding(20)
    }
    .background(Color.white)
}
