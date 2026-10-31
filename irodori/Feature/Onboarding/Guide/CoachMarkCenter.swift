//
//  CoachMarkCenter.swift
//  irodori
//
//  初めてホームを使うときのツールチップ (コーチマーク) の状態。
//  - 出すのは初回オンボーディングを終えたユーザーだけ (markEligible)。既存ユーザーには出さない
//  - 同じツアーは二度と出さない (UserDefaults に記録)
//  - 部品は .coachFrame(.recipes) で画面上の位置を知らせ、MainTabView の CoachMarkOverlay が吹き出しを描く
//
//  ツアー形式: ホームが開いたら、操作を待たずに始める。暗くして指す部品だけをくり抜き、
//  相棒のひとこと → 3案 → 服を教えて → カメラ の順に「つぎへ」で進む。最後は「撮ってみる」。
//  - 画面にまだ無い部品 (3案の読み込みが遅いなど) は飛ばして進む
//  - 「撮ってみる」を選んだときだけ、続けてカメラ画面で撮り方を案内する。
//    それ以外で終えたら、あとでカメラを開いたときに案内が急に出ることはない (画面の移動で出さない)
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
            return .init(target: target, title: "相棒のひとこと", body: "タップで相棒画面へ。覚えたことや、ふたりの記録が見られるよ")
        case .recipes:
            return .init(target: target, title: "相棒からの3案", body: "気温と手持ちの服から組んだよ。気に入ったら「着る」、違えば「ちょっと違う」")
        case .feedback:
            return .init(target: target, title: "理由を教えてね", body: "選んだ理由はちゃんと覚えて、次の3案に活かすよ")
        case .growth:
            return .init(target: target, title: "服を教えて", body: "写真や定番アイテムで教えてくれると、あなたの服だけで組める案が増えるよ",
                         action: .pickPhotosFromHome, actionLabel: "写真から教える")
        case .camera:
            return .init(target: target, title: "着た日は1枚撮ろう", body: "全身を撮ると、着回しのクセや好きな色を覚えるよ。ふたりの記録にも残るね",
                         action: .openCamera, actionLabel: "撮ってみる")
        case .cameraShutter:
            return .init(target: target, title: "全身を1枚", body: "鏡越しでもOK。足もとまで入ると、服をよく覚えられるよ")
        case .cameraPicker:
            return .init(target: target, title: "撮った写真でもOK", body: "写真フォルダから、AIがあなたの全身写真を探して選んでくれるよ",
                         action: .pickPhotosInCamera, actionLabel: "写真から選ぶ", laterLabel: "カメラで撮る")
        }
    }
}

@MainActor
@Observable
final class CoachMarkCenter {
    static let shared = CoachMarkCenter()

    /// いま前面にある画面 (ツールチップはその画面の部品だけ指す)
    enum Screen { case home, camera, other }

    private static let eligibleKey = "coachMark.eligible"
    private static let seenKey = "coachMark.seen"
    private static let homeTour: [CoachTip] = [.of(.partner), .of(.recipes), .of(.growth), .of(.camera)]
    private static let cameraTour: [CoachTip] = [.of(.cameraShutter), .of(.cameraPicker)]

    /// 部品の位置 (グローバル座標)。タブバーのカメラは CoachMarkOverlay が計算する
    var frames: [CoachTarget: CGRect] = [:]
    /// いま出しているツールチップ
    private(set) var current: CoachTip?
    /// ツアーの何番目か (0 始まり)。ツアーをしていないときは nil
    private(set) var tourStep: Int?
    private var tour: [CoachTip] = []
    private var tourKey = ""
    /// 前面の画面 (MainTabView が知らせる)
    var front: Screen = .home
    /// ツアー型で、画面外の部品までスクロールしてほしいとき
    var scrollRequest: CoachTarget?
    /// ツールチップのボタンで始めた行動 (受け取った画面が実行して nil に戻す)
    var pendingAction: CoachAction?

    private var seen: Set<String>

    private init() {
        seen = Set(UserDefaults.standard.stringArray(forKey: Self.seenKey) ?? [])
    }

    var tourTotal: Int { tour.count }
    var isLastTourStep: Bool { tourStep.map { $0 == tour.count - 1 } ?? false }

    private var isEligible: Bool { UserDefaults.standard.bool(forKey: Self.eligibleKey) }

    /// 初回オンボーディング (4つの質問 → 相棒誕生) を終えたときに呼ぶ
    func markEligible() {
        UserDefaults.standard.set(true, forKey: Self.eligibleKey)
    }

    /// ホームが開いた (3案が出た・読み込みを待ちきれなかった)。操作を待たずにツアーを始める
    func homeReady() {
        guard isEligible else { return }
        startTour(Self.homeTour, key: "tour")
    }

    /// カメラ画面を開いた。ホームのツアーの最後に「撮ってみる」を選んだときだけ、続けて撮り方を案内する
    func cameraOpened() {
        guard isEligible else { return }
        startTour(Self.cameraTour, key: "cameraTour")
    }

    /// 「つぎへ」、暗幕のタップ。画面にまだ無い部品は飛ばす
    func next() {
        guard let step = tourStep else { return }
        guard let n = nextAvailable(after: step) else { finishTour(); return }
        let tip = tour[n]
        if tip.target == .growth { scrollRequest = .growth }
        withAnimation(.easeInOut(duration: 0.25)) {
            tourStep = n
            current = tip
        }
    }

    /// 行動ボタン: ツールチップを閉じて、その画面に行動を渡す
    func perform(_ action: CoachAction) {
        Haptic.impact(.medium)
        finishTour(continuingToCamera: action == .openCamera)
        pendingAction = action
    }

    /// ツアーをやめる (スキップ・「あとで」)
    func skipTour() { finishTour() }

    private func startTour(_ tips: [CoachTip], key: String) {
        guard tourStep == nil, !seen.contains(key) else { return }
        tour = tips
        tourKey = key
        // 画面の部品がまだ1つも無ければ始めない (記録もしない。次に呼ばれたときにやり直す)。
        // タブバーのカメラだけでは始めない (ホームが描かれる前に、カメラの説明だけで終わらないように)
        guard tips.contains(where: { $0.target != .camera && isAvailable($0.target) }),
              let first = nextAvailable(after: -1) else { tour = []; return }
        if tips[first].target == .growth { scrollRequest = .growth }
        withAnimation(.easeInOut(duration: 0.25)) {
            tourStep = first
            current = tips[first]
        }
    }

    /// その部品をいま指せるか。タブバーのカメラはいつでも指せる。ほかは位置が分かっているものだけ
    private func isAvailable(_ target: CoachTarget) -> Bool {
        if target == .camera { return true }
        guard let rect = frames[target] else { return false }
        return rect.height > 0
    }

    private func nextAvailable(after step: Int) -> Int? {
        var n = step + 1
        while n < tour.count {
            if isAvailable(tour[n].target) { return n }
            n += 1
        }
        return nil
    }

    /// continuingToCamera: ホームのツアーの最後に「撮ってみる」を選んだ (カメラ画面で続きを案内する)
    private func finishTour(continuingToCamera: Bool = false) {
        markSeen(tourKey)
        // ホームのツアーを終えたら、カメラの案内はあとで急に出さない (「撮ってみる」のときだけ続けて出す)
        if tourKey == "tour" && !continuingToCamera { markSeen("cameraTour") }
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

    /// 別の人のアカウントに切り替わったとき: 表示済みの記録を消す (前の人の「見た」を引き継がない)
    func resetForNewAccount() {
        seen = []
        current = nil
        tourStep = nil
        tour = []
        pendingAction = nil
    }

    #if DEBUG
    /// 動作確認用: 新規ユーザーと同じ状態に戻す
    func resetForDebug() {
        UserDefaults.standard.set(true, forKey: Self.eligibleKey)
        seen = []
        UserDefaults.standard.removeObject(forKey: Self.seenKey)
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
