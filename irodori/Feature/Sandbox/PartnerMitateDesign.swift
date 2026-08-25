//
//  PartnerMitateDesign.swift
//  irodori
//
//  相棒画面ブラッシュアップ第2版: 「今日の見立て」セクション。
//  第1版 (PartnerMannequinDesigns.swift の3案) は画面ごと差し替える案で不採用。
//  本版は **今の相棒画面 (ゲージ → あいさつ → アドバイス → きろく) に
//  コーデ提案セクションを1つ追加する** 形に改める。
//
//  要件:
//  - マネキン = 試着画像 (TryOn)。相棒の提案を「あなたが着た姿」で見せる
//  - 判断根拠は丁寧に: 相棒が考えた順 (天気 → かぶり回避 → あなたの定数) を
//    番号付きの完全な文章で説明する (番号 = 実際の選定パイプラインの順序)
//  - 変数モデルは維持: 文脈は「きょうは▾」1タップ、消した変数は文中で申告
//
//  試着画像の運用 (本番実装時):
//  - 1日1回だけ自動生成し TryOnCache にキャッシュ (約5円/日)。再訪は即表示
//  - 顔未登録: コラージュ表示 + 「自分の姿で見る」登録導線 (.tryOnFlow を流用)
//  - 生成失敗/上限時: コラージュへ静かにフォールバック
//
//  Preview: 「相棒画面に組み込み」で現行画面の並びの中で確認する。
//

import SwiftUI
import Kingfisher

// MARK: - モックデータ

enum MitateSandbox {
    /// 試着画像のスタンドイン (本番は TryOn 生成画像)
    static let tryOnImageURL = "https://i.pinimg.com/736x/a6/5a/50/a65a50686f1c10f5c98f2bedd434bf1e.jpg"

    static let headline = "きょうは、Iラインのネイビー×白。"

    /// 相棒が考えた順 = 実際の選定パイプラインの順序 (環境 → 制約 → 定数)
    static let reasoningSteps: [(number: String, label: String, sentence: String)] = [
        ("1", "天気をみる",
         "最高26°の晴れ。日中は暑くなるので、長袖シャツ1枚でちょうどいい日です。"),
        ("2", "かぶりを消す",
         "おととい白シャツを着ていたので、今日はバンドカラーの1枚に替えました。"),
        ("3", "あなたの定数にあてはめる",
         "手持ちの6割を占めるネイビー×白をベースに、骨格ストレートさんが得意な縦のIラインでまとめています。"),
    ]

    static let items: [(slot: String, name: String, color: Color, symbol: String)] = [
        ("トップス", "白 バンドカラーシャツ", Color(white: 0.97), "tshirt"),
        ("ボトムス", "ネイビー テーパード", Color(red: 0.16, green: 0.20, blue: 0.32), "figure.walk"),
        ("シューズ", "ブラウン ローファー", Color(red: 0.42, green: 0.29, blue: 0.20), "shoe"),
    ]

    static let contextOptions = ["いつもの一日", "しごと きっちりめ", "デート・おでかけ", "遠出・よく歩く"]
}

// MARK: - 「今日の見立て」セクション

enum MitateVisual {
    case tryOn      // 試着画像あり (顔登録済み・生成完了)
    case loading    // 生成中
    case noFace     // 顔未登録 → コラージュ + 登録導線
}

struct PartnerMitateSection: View {
    var visual: MitateVisual = .tryOn

    @State private var context = MitateSandbox.contextOptions[0]
    @State private var showAllReasons = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            visualArea
            headlineBlock
            reasoningCard
            itemsRow
            ctaRow
        }
    }

    // ── ヘッダー: タイトル + 文脈1タップ ──
    private var header: some View {
        HStack(spacing: 8) {
            Text("今日の見立て")
                .font(.system(size: 16, weight: .bold))
            Spacer()
            Menu {
                ForEach(MitateSandbox.contextOptions, id: \.self) { option in
                    Button(option) {
                        Haptic.selection()
                        context = option
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("きょうは \(context)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // ── マネキン = 試着画像 ──
    @ViewBuilder
    private var visualArea: some View {
        switch visual {
        case .tryOn:
            ZStack(alignment: .bottomTrailing) {
                KFImage(URL(string: MitateSandbox.tryOnImageURL))
                    .resizable()
                    .placeholder { Color.gray.opacity(0.12) }
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text("AI試着イメージ")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45))
                    .clipShape(Capsule())
                    .padding(10)
            }
        case .loading:
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.08))
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("あなたが着た姿を準備しています…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
        case .noFace:
            VStack(spacing: 10) {
                collagePlaceholder
                Button {
                    Haptic.impact(.soft)
                } label: {
                    Label("顔写真を登録して、自分が着た姿で見る", systemImage: "person.crop.circle.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var collagePlaceholder: some View {
        VStack(spacing: 8) {
            ForEach(MitateSandbox.items, id: \.slot) { item in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: item.symbol)
                                .font(.system(size: 16))
                                .foregroundStyle(item.slot == "トップス" ? Color.gray.opacity(0.5) : .white.opacity(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.08), lineWidth: 1))
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.07), lineWidth: 1))
    }

    // ── 題字 ──
    private var headlineBlock: some View {
        Text(MitateSandbox.headline)
            .font(.system(size: 15, weight: .bold))
    }

    // ── 相棒はこう考えました (丁寧な根拠) ──
    private var reasoningCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("相棒はこう考えました")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)
            ForEach(Array(MitateSandbox.reasoningSteps.enumerated()), id: \.offset) { index, step in
                ReasoningStepRow(step: step)
                if index < MitateSandbox.reasoningSteps.count - 1 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 1.5, height: 10)
                        .padding(.leading, 10)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.07), lineWidth: 1))
    }

    // ── 使っているアイテム ──
    private var itemsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MitateSandbox.items, id: \.slot) { item in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(item.color)
                            .frame(width: 26, height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.08), lineWidth: 1))
                        Text(item.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // ── CTA ──
    private var ctaRow: some View {
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
                    .frame(width: 104)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

/// 根拠1ステップ: 番号 + 見出し + 完全な文章。
/// 番号は飾りではなく、実際の選定順 (環境 → 制約 → 定数) を表す。
private struct ReasoningStepRow: View {
    let step: (number: String, label: String, sentence: String)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step.number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.black))
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.system(size: 12, weight: .bold))
                Text(step.sentence)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - 現行の相棒画面に組み込んだ形 (配置確認用レプリカ)

struct PartnerMitateInContext: View {
    var visual: MitateVisual = .tryOn

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("相棒")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                // 現行のゲージセクションの簡易レプリカ (実物は PartnerPattern3GrowthView)
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

                // 現行のあいさつ (実物は PartnerTalkBubble)
                PartnerTalkBubble(text: "おはよう。きょうの分の見立て、できてるよ。")

                // ★ 新設: 今日の見立て
                PartnerMitateSection(visual: visual)

                // 既存セクションの位置関係を示すダミー
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

#Preview("相棒画面に組み込み (試着)") {
    PartnerMitateInContext(visual: .tryOn)
}

#Preview("顔未登録 (コラージュ+導線)") {
    PartnerMitateInContext(visual: .noFace)
}

#Preview("生成中") {
    PartnerMitateInContext(visual: .loading)
}
