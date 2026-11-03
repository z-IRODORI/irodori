//
//  FullBodyScanStore.swift
//  irodori
//
//  写真フォルダから「本人の全身写真」を探す処理を、画面を閉じても裏で続けるための置き場。
//  - 探している間は画面の下にトースト (FullBodyScanToast) を出し、ほかの操作ができるようにする
//  - 見つかった枚数はその場で増やす
//  - 見つかった写真は ID (PHAsset.localIdentifier) だけを端末に保存し、あとからいつでも選んで送れるようにする
//    (写真そのものは保存しない。端末の外にも送らない)
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class FullBodyScanStore {
    static let shared = FullBodyScanStore()

    enum Phase: Equatable { case idle, scanning, finished }

    /// 保存する候補 (写真の ID と本人らしさ)
    struct SavedCandidate: Codable, Hashable, Identifiable {
        let id: String
        let similarity: Float
    }

    private(set) var phase: Phase = .idle
    /// 0...1
    private(set) var progress: Double = 0
    /// 今回の検索で見つかった枚数
    private(set) var foundCount = 0
    /// これまでに見つけた全身写真 (本人らしい順)
    private(set) var saved: [SavedCandidate] = []
    /// トーストを閉じた (スワイプ・✕)。次の検索を始めるとまた出す
    var isToastHidden = false
    /// 完了トーストを押した → 候補の画面を開く (MainTabView が見て開く)
    var openResultRequest = false

    private var task: Task<Void, Never>?
    private let service = FullBodyPickerService()
    private static let savedKey = "fullBodyPicker.savedCandidates"
    private static let measuredRateKey = "fullBodyPicker.secondsPerPhoto"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.savedKey),
           let list = try? JSONDecoder().decode([SavedCandidate].self, from: data) {
            saved = list
        }
    }

    var isScanning: Bool { phase == .scanning }

    /// 検索を始める。顔が読めなければ false (呼び出し側が案内を出す)
    func start(faceImage: UIImage, months: Int, photoCount: Int) async -> Bool {
        guard !isScanning else { return true }
        let service = self.service
        let emb = await Task.detached(priority: .userInitiated) {
            service.targetEmbedding(from: faceImage)
        }.value
        guard let emb else { return false }

        phase = .scanning
        progress = 0
        foundCount = 0
        isToastHidden = false
        task = Task { [weak self] in
            let start = Date()
            _ = await service.pickFullBodyPhotos(
                targetEmbedding: emb, months: months,
                progress: { p in Task { @MainActor in self?.progress = p } },
                onFound: { c in Task { @MainActor in self?.add(c) } }
            )
            // 次回の見積もりに使うため、1枚あたりの秒数を残す
            let elapsed = Date().timeIntervalSince(start)
            if photoCount >= 20 {
                UserDefaults.standard.set(elapsed / Double(photoCount), forKey: Self.measuredRateKey)
            }
            await MainActor.run {
                guard let self, self.phase == .scanning else { return }
                self.progress = 1
                self.phase = .finished
            }
        }
        return true
    }

    /// 検索をやめる (そこまでに見つけた写真は残す)
    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
        progress = 0
    }

    /// トーストを閉じる (検索中なら裏で続ける。終わっていれば片付ける)
    func hideToast() {
        if phase == .finished { phase = .idle }
        isToastHidden = true
    }

    /// 完了トーストを押した
    func openResult() {
        phase = .idle
        openResultRequest = true
    }

    /// 送った・要らない写真を候補から外す
    func remove(_ ids: Set<String>) {
        saved.removeAll { ids.contains($0.id) }
        persist()
    }

    private func add(_ c: FullBodyCandidate) {
        foundCount += 1
        if let i = saved.firstIndex(where: { $0.id == c.id }) {
            if c.similarity > saved[i].similarity { saved[i] = SavedCandidate(id: c.id, similarity: c.similarity) }
        } else {
            saved.append(SavedCandidate(id: c.id, similarity: c.similarity))
        }
        saved.sort { $0.similarity > $1.similarity }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.savedKey)
        }
    }
}

// MARK: - トースト

/// 全身写真を探している間、画面の下に出すトースト。
/// 背景を左から右へ塗って進み具合を見せ、進むほど色をピンクに近づける。
struct FullBodyScanToast: View {
    private var store = FullBodyScanStore.shared

    var body: some View {
        if store.phase != .idle, !store.isToastHidden {
            Button {
                guard store.phase == .finished else { return }
                Haptic.impact(.soft)
                store.openResult()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: store.phase == .finished ? "person.crop.rectangle.stack.fill" : "sparkle.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .opacity(0.85)
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    if store.phase == .finished {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Button {
                            Haptic.impact(.soft)
                            store.cancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("探すのをやめる")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(width: min(UIScreen.main.bounds.width - 48, 340))
                .background(fillBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .swipeToDismiss(edge: .bottom) { store.hideToast() }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeOut(duration: 0.3), value: store.progress)
            .animation(.easeOut(duration: 0.3), value: store.foundCount)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)。\(subtitle)")
        }
    }

    private var title: String {
        store.phase == .finished ? "全身写真を探し終わりました" : "全身写真を探しています…"
    }

    private var subtitle: String {
        if store.phase == .finished {
            return store.foundCount > 0 ? "\(store.foundCount)枚見つかりました ・ タップで選ぶ" : "見つかりませんでした"
        }
        return "\(store.foundCount)枚見つかりました ・ \(Int(store.progress * 100))%"
    }

    /// 進み具合のぶんだけ左から塗る。色は灰 → ピンクへ近づける
    private var fillBackground: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.88)
                Rectangle()
                    .fill(Self.fillColor(store.progress))
                    .frame(width: geo.size.width * max(0.04, store.progress))
            }
        }
    }

    static func fillColor(_ p: Double) -> Color {
        // 灰 (0.35, 0.35, 0.38) → ピンク (1.0, 0.27, 0.42)
        let t = min(max(p, 0), 1)
        return Color(red: 0.35 + (1.0 - 0.35) * t,
                     green: 0.35 + (0.27 - 0.35) * t,
                     blue: 0.38 + (0.42 - 0.38) * t)
    }
}
