//
//  CoachMarkCenter.swift
//  irodori
//
//  初めてホームを使うときのツールチップ (コーチマーク) の状態。
//  - 出すのは初回オンボーディングを終えたユーザーだけ (markEligible)。既存ユーザーには出さない
//  - 同じツールチップは二度と出さない (UserDefaults に記録)
//  - 部品は .coachFrame(.recipes) で画面上の位置を知らせ、MainTabView の CoachMarkOverlay が吹き出しを描く
//  - 最後は「やってみる」ボタンにして、データ入力 (撮る・写真から教える) を次の行動にする
//
//  ホームの出し方は2つ (既定は「その場型」):
//  - その場型: 必要になった瞬間に1つずつ。暗くしない
//      3案が出た → 相棒のひとこと / 相棒カードが見えた → 服を教えて (写真から教える) /
//      「ちょっと違う」→ 理由を教えて / 「着る」の送り出しを閉じた → 着た日は1枚 (撮ってみる)
//  - ツアー型: 3案が出た直後に4つを順に。暗くして1つずつくり抜き、最後は「撮ってみる」
//  カメラ画面: 初めて開いたときに2つ (シャッター → 写真から選ぶ)。どちらの型でも出す
//

import SwiftUI

enum CoachTarget: String, CaseIterable {
    case partner, recipes, feedback, growth, camera
    case cameraShutter, cameraPicker

    /// ScrollViewReader で送るときの id
    var scrollID: String { "coach.\(rawValue)" }

    /// どの画面の部品か
    var screen: CoachMarkCenter.Screen {
        switch self {
        case .cameraShutter, .cameraPicker: return .camera
        default: return .home
        }
    }
}

/// ツールチップのボタンから始めるデータ入力
enum CoachAction: Equatable {
    /// カメラ画面を開く
    case openCamera
    /// ホームから「AIで写真を探す」を開く
    case pickPhotosFromHome
    /// カメラ画面で「AIで写真を探す」を開く
    case pickPhotosInCamera
}

struct CoachTip: Equatable {
    let target: CoachTarget
    let title: String
    let body: String
    /// 主ボタンで始める行動 (nil なら「つぎへ」「OK」)
    var action: CoachAction? = nil
    var actionLabel: String = ""
    /// 行動ボタンの横の控えめなボタン
    var laterLabel: String = "あとで"

    static func of(_ target: CoachTarget) -> CoachTip {
        switch target {
        case .partner:
            return .init(target: target, title: "相棒のひとこと", body: "タップで相棒画面へ")
        case .recipes:
            return .init(target: target, title: "相棒からの3案", body: "「着る」で決定。違えば「ちょっと違う」")
        case .feedback:
            return .init(target: target, title: "理由を教えてね", body: "次の3案に活かすよ")
        case .growth:
            return .init(target: target, title: "服を教えて", body: "あなたの服で組める案が増えるよ",
                         action: .pickPhotosFromHome, actionLabel: "写真から教える")
        case .camera:
            return .init(target: target, title: "着た日は1枚撮ろう", body: "着回しのクセを覚えるよ",
                         action: .openCamera, actionLabel: "撮ってみる")
        case .cameraShutter:
            return .init(target: target, title: "全身を1枚", body: "鏡越しでもOK")
        case .cameraPicker:
            return .init(target: target, title: "撮った写真でもOK", body: "AIが全身写真を探すよ",
                         action: .pickPhotosInCamera, actionLabel: "写真から選ぶ", laterLabel: "カメラで撮る")
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

    /// いま前面にある画面 (ツールチップはその画面の部品だけ指す)
    enum Screen { case home, camera, other }

    static let styleKey = "coachMark.style"
    private static let eligibleKey = "coachMark.eligible"
    private static let seenKey = "coachMark.seen"
    private static let homeTour: [CoachTip] = [.of(.partner), .of(.recipes), .of(.growth), .of(.camera)]
    private static let cameraTour: [CoachTip] = [.of(.cameraShutter), .of(.cameraPicker)]

    /// 部品の位置 (グローバル座標)。タブバーのカメラは CoachMarkOverlay が計算する
    var frames: [CoachTarget: CGRect] = [:]
    /// いま出しているツールチップ
    private(set) var current: CoachTip?
    /// ツアーの何番目か (0 始まり)。その場型では nil
    private(set) var tourStep: Int?
    private var tour: [CoachTip] = []
    private var tourKey = ""
    /// 前面の画面 (MainTabView が知らせる)
    var front: Screen = .home
    /// ツアー型で、画面外の部品までスクロールしてほしいとき
    var scrollRequest: CoachTarget?
    /// ツールチップのボタンで始めた行動 (受け取った画面が実行して nil に戻す)
    var pendingAction: CoachAction?

    private var queue: [CoachTip] = []
    private var seen: Set<String>

    private init() {
        seen = Set(UserDefaults.standard.stringArray(forKey: Self.seenKey) ?? [])
    }

    var style: Style {
        Style(rawValue: UserDefaults.standard.string(forKey: Self.styleKey) ?? "") ?? .contextual
    }

    var tourTotal: Int { tour.count }
    var isLastTourStep: Bool { tourStep.map { $0 == tour.count - 1 } ?? false }

    private var isEligible: Bool { UserDefaults.standard.bool(forKey: Self.eligibleKey) }

    /// 初回オンボーディング (4つの質問 → 相棒誕生) を終えたときに呼ぶ
    func markEligible() {
        UserDefaults.standard.set(true, forKey: Self.eligibleKey)
    }

    /// ホームに3案が出た
    func homeReady() {
        guard isEligible else { return }
        switch style {
        case .tour: startTour(Self.homeTour, key: "tour")
        case .contextual: trigger(.partner)
        }
    }

    /// カメラ画面を開いた (初めてのときだけ、撮り方と写真からの選び方を案内する)
    func cameraOpened() {
        guard isEligible else { return }
        startTour(Self.cameraTour, key: "cameraTour")
    }

    /// その場型: その部品が必要になった瞬間に1回だけ出す
    func trigger(_ target: CoachTarget) {
        guard isEligible, style == .contextual, !seen.contains(target.rawValue) else { return }
        markSeen(target.rawValue)
        queue.append(.of(target))
        if current == nil { showNextQueued() }
    }

    /// 「つぎへ」「OK」、ツアーの暗幕タップ
    func next() {
        if let step = tourStep {
            let n = step + 1
            guard n < tour.count else { finishTour(); return }
            let tip = tour[n]
            if tip.target == .growth { scrollRequest = .growth }
            withAnimation(.easeInOut(duration: 0.25)) {
                tourStep = n
                current = tip
            }
        } else {
            showNextQueued()
        }
    }

    /// 行動ボタン: ツールチップを閉じて、その画面に行動を渡す
    func perform(_ action: CoachAction) {
        Haptic.impact(.medium)
        if tourStep != nil { finishTour() } else { showNextQueued() }
        pendingAction = action
    }

    /// ツアーをやめる (スキップ・「あとで」)
    func skipTour() { finishTour() }

    private func startTour(_ tips: [CoachTip], key: String) {
        guard tourStep == nil, !seen.contains(key), let first = tips.first else { return }
        tour = tips
        tourKey = key
        withAnimation(.easeInOut(duration: 0.25)) {
            tourStep = 0
            current = first
        }
    }

    private func showNextQueued() {
        withAnimation(.easeInOut(duration: 0.25)) {
            current = queue.isEmpty ? nil : queue.removeFirst()
        }
    }

    private func finishTour() {
        markSeen(tourKey)
        withAnimation(.easeInOut(duration: 0.25)) {
            tourStep = nil
            current = nil
        }
        tour = []
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
        tour = []
        pendingAction = nil
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
