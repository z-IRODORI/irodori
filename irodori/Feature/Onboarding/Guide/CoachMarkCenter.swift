//
//  CoachMarkCenter.swift
//  irodori
//
//  初めてホームを使うときのツールチップ (コーチマーク) の状態。
//  - 出すのは初回オンボーディングを終えたユーザーだけ (markEligible)。既存ユーザーには出さない
//  - 同じツールチップは二度と出さない (UserDefaults に記録)
//  - 部品は .coachFrame(.recipes) で画面上の位置を知らせ、MainTabView の CoachMarkOverlay が吹き出しを描く
//
//  出し方は2つ (既定は「その場型」):
//  - その場型: 必要になった瞬間に1つずつ。暗くしない
//      ホームに3案が出た → 相棒のひとこと / 相棒カードが見えた → 服を教えて /
//      「ちょっと違う」を押した → 理由で組み直す / 「着る」の送り出しを閉じた → 着た日は撮ろう
//  - ツアー型: 3案が出た直後に4つを順に。画面を暗くして1つずつくり抜く
//

import SwiftUI

enum CoachTarget: String, CaseIterable {
    case partner, recipes, feedback, growth, camera

    /// ScrollViewReader で送るときの id
    var scrollID: String { "coach.\(rawValue)" }
}

struct CoachTip: Equatable {
    let target: CoachTarget
    let title: String
    let body: String

    static func of(_ target: CoachTarget) -> CoachTip {
        switch target {
        case .partner:
            return .init(target: target, title: "相棒のひとこと",
                         body: "タップすると相棒画面へ。覚えたことや、ふたりの記録が見られるよ")
        case .recipes:
            return .init(target: target, title: "次に着る日の3案",
                         body: "気温と手持ちの服から組んだよ。気に入ったら「着る」、ピンとこなければ「ちょっと違う」を押してね")
        case .feedback:
            return .init(target: target, title: "教えてくれてありがとう",
                         body: "理由を選ぶと、その案を入れ替えて、次の3案にも活かすよ")
        case .growth:
            return .init(target: target, title: "服を教えてほしいな",
                         body: "写真や定番アイテムで服を教えると、あなたの服だけで組める案が増えるよ")
        case .camera:
            return .init(target: target, title: "着た日はここから1枚",
                         body: "全身を撮ると着回しのクセがわかるよ。ふたりの記録にも残るね")
        }
    }
}

@MainActor
@Observable
final class CoachMarkCenter {
    static let shared = CoachMarkCenter()

    enum Style: String, CaseIterable, Identifiable {
        case contextual, tour
        var id: String { rawValue }
        var label: String { self == .contextual ? "その場型" : "ツアー型" }
    }

    static let styleKey = "coachMark.style"
    private static let eligibleKey = "coachMark.eligible"
    private static let seenKey = "coachMark.seen"
    private static let tourTips: [CoachTip] = [.of(.partner), .of(.recipes), .of(.growth), .of(.camera)]

    /// 部品の位置 (グローバル座標)。カメラはタブバーの中なので CoachMarkOverlay が計算する
    var frames: [CoachTarget: CGRect] = [:]
    /// いま出しているツールチップ
    private(set) var current: CoachTip?
    /// ツアー型の何番目か (0 始まり)。その場型では nil
    private(set) var tourStep: Int?
    /// ホームが前面にあるとき true (ほかのタブ・push 先では隠す)
    var homeIsFront = true
    /// ツアー型で、画面外の部品までスクロールしてほしいとき
    var scrollRequest: CoachTarget?

    private var queue: [CoachTip] = []
    private var seen: Set<String>

    private init() {
        seen = Set(UserDefaults.standard.stringArray(forKey: Self.seenKey) ?? [])
    }

    var style: Style {
        Style(rawValue: UserDefaults.standard.string(forKey: Self.styleKey) ?? "") ?? .contextual
    }

    var tourTotal: Int { Self.tourTips.count }

    private var isEligible: Bool { UserDefaults.standard.bool(forKey: Self.eligibleKey) }

    /// 初回オンボーディング (4つの質問 → 相棒誕生) を終えたときに呼ぶ
    func markEligible() {
        UserDefaults.standard.set(true, forKey: Self.eligibleKey)
    }

    /// ホームに3案が出た
    func homeReady() {
        guard isEligible else { return }
        switch style {
        case .tour:
            guard tourStep == nil, !seen.contains("tour") else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                tourStep = 0
                current = Self.tourTips[0]
            }
        case .contextual:
            trigger(.partner)
        }
    }

    /// その場型: その部品が必要になった瞬間に1回だけ出す
    func trigger(_ target: CoachTarget) {
        guard isEligible, style == .contextual, !seen.contains(target.rawValue) else { return }
        markSeen(target.rawValue)
        queue.append(.of(target))
        if current == nil { showNextQueued() }
    }

    /// 吹き出しの「つぎへ」「OK」、ツアー型の暗幕タップ
    func next() {
        if let step = tourStep {
            let n = step + 1
            guard n < Self.tourTips.count else { finishTour(); return }
            let tip = Self.tourTips[n]
            if tip.target == .growth { scrollRequest = .growth }
            withAnimation(.easeInOut(duration: 0.25)) {
                tourStep = n
                current = tip
            }
        } else {
            showNextQueued()
        }
    }

    func skipTour() { finishTour() }

    private func showNextQueued() {
        withAnimation(.easeInOut(duration: 0.25)) {
            current = queue.isEmpty ? nil : queue.removeFirst()
        }
    }

    private func finishTour() {
        markSeen("tour")
        withAnimation(.easeInOut(duration: 0.25)) {
            tourStep = nil
            current = nil
        }
    }

    private func markSeen(_ key: String) {
        seen.insert(key)
        UserDefaults.standard.set(Array(seen), forKey: Self.seenKey)
    }

    #if DEBUG
    /// 動作確認用: 新規ユーザーと同じ状態に戻す
    func resetForDebug() {
        UserDefaults.standard.set(true, forKey: Self.eligibleKey)
        seen = []
        UserDefaults.standard.removeObject(forKey: Self.seenKey)
        queue = []
        current = nil
        tourStep = nil
    }
    #endif
}

// MARK: - 位置を知らせる

private struct CoachFrameReporter: ViewModifier {
    let target: CoachTarget
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                CoachMarkCenter.shared.frames[target] = rect
            }
        } else {
            content
        }
    }
}

extension View {
    /// この部品をツールチップで指せるようにする (active が false の間は知らせない)
    func coachFrame(_ target: CoachTarget, active: Bool = true) -> some View {
        modifier(CoachFrameReporter(target: target, active: active))
    }
}
