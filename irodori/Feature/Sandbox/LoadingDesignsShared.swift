//
//  LoadingDesignsShared.swift
//  irodori - Sandbox
//
//  コーデ提案 (レビュー作成) 中のローディング画面 5 案で共有するモックと小物.
//  本実装時は CoordinateReviewViewModel の segment() / API 進行に phase を対応させる:
//    .scanning       → segment() 実行中
//    .topsDetected   → topsUIImage 確定
//    .bottomsDetected → bottomsUIImage 確定
//    .analyzing      → FashionReviewClient.post() 待ち (8〜10 秒)
//

import SwiftUI

// MARK: - デモ用フェーズ

enum LoadingDemoPhase: Int, CaseIterable, Comparable {
    case scanning
    case topsDetected
    case bottomsDetected
    case analyzing

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - 共有アセット / ブランドカラー

enum LoadingSandbox {
    /// CameraView の AI ボタンと同じブランドグラデーション
    static let brandPink = Color(red: 1.0, green: 0.27, blue: 0.42)
    static let brandOrange = Color(red: 1.0, green: 0.45, blue: 0.30)
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [brandPink, brandOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// サンプル全身画像と、その画像上のトップス / ボトムス位置 (正規化座標)
    static let sampleImage = UIImage(resource: .coordinate2)
    static let topsRect = CGRect(x: 0.29, y: 0.19, width: 0.38, height: 0.24)
    static let bottomsRect = CGRect(x: 0.34, y: 0.38, width: 0.37, height: 0.55)

    static let sampleTopsImage = crop(sampleImage, normalized: topsRect)
    static let sampleBottomsImage = crop(sampleImage, normalized: bottomsRect)

    /// 正規化 rect で UIImage を切り出す (デモ用. 本実装では segment() の topsUIImage / bottomsUIImage をそのまま使う)
    static func crop(_ image: UIImage, normalized rect: CGRect) -> UIImage {
        let pixelRect = CGRect(
            x: rect.minX * image.size.width,
            y: rect.minY * image.size.height,
            width: rect.width * image.size.width,
            height: rect.height * image.size.height
        )
        let renderer = UIGraphicsImageRenderer(size: pixelRect.size)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -pixelRect.minX, y: -pixelRect.minY))
        }
    }
}

// MARK: - フェーズ進行ドライバ (デモではループ再生)

private struct LoadingDemoPhaseDriver: ViewModifier {
    @Binding var phase: LoadingDemoPhase
    let durations: [LoadingDemoPhase: TimeInterval]

    func body(content: Content) -> some View {
        content.task {
            while !Task.isCancelled {
                for p in LoadingDemoPhase.allCases {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { phase = p }
                    try? await Task.sleep(for: .seconds(durations[p] ?? 2.0))
                    if Task.isCancelled { return }
                }
            }
        }
    }
}

extension View {
    /// scanning → tops → bottoms → analyzing をループ再生する
    func loadingDemoPhaseDriver(
        _ phase: Binding<LoadingDemoPhase>,
        durations: [LoadingDemoPhase: TimeInterval] = [
            .scanning: 2.4, .topsDetected: 2.0, .bottomsDetected: 2.0, .analyzing: 3.2,
        ]
    ) -> some View {
        modifier(LoadingDemoPhaseDriver(phase: phase, durations: durations))
    }
}

// MARK: - 共通ヘッダー

struct LoadingDemoHeader: View {
    let title: String
    let subtitle: String
    var foreground: Color = .black

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(foreground)
            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(foreground.opacity(0.5))
        }
    }
}

// MARK: - 3 ステップインジケータ (スキャン → 検出 → AIレビュー)

struct LoadingDemoStepBar: View {
    let phase: LoadingDemoPhase
    var foreground: Color = .black

    var body: some View {
        HStack(spacing: 8) {
            stepChip(label: "スキャン", isDone: phase >= .topsDetected, isActive: phase == .scanning)
            connector(isDone: phase >= .topsDetected)
            stepChip(label: "アイテム検出", isDone: phase >= .analyzing, isActive: phase == .topsDetected || phase == .bottomsDetected)
            connector(isDone: phase >= .analyzing)
            stepChip(label: "AIレビュー", isDone: false, isActive: phase == .analyzing)
        }
    }

    private func stepChip(label: String, isDone: Bool, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
            } else if isActive {
                Circle().frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(isDone || isActive ? LoadingSandbox.brandPink : foreground.opacity(0.35))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isDone || isActive ? LoadingSandbox.brandPink.opacity(0.12) : foreground.opacity(0.06)))
        .clipShape(Capsule())
    }

    private func connector(isDone: Bool) -> some View {
        Rectangle()
            .fill(isDone ? LoadingSandbox.brandPink.opacity(0.6) : foreground.opacity(0.15))
            .frame(width: 14, height: 2)
    }
}

// MARK: - グラデーションプログレスバー

struct LoadingDemoProgressBar: View {
    /// 0...1
    let progress: CGFloat
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.12))
                Capsule()
                    .fill(LoadingSandbox.brandGradient)
                    .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - 下向きしっぽ付き吹き出し (相棒コメント用)

struct LoadingDemoBubble: View {
    let text: String
    var maxWidth: CGFloat = 220

    var body: some View {
        VStack(spacing: -1) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
            Triangle()
                .fill(.white)
                .frame(width: 14, height: 8)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 2)
        }
        .frame(maxWidth: maxWidth)
    }

    struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                p.closeSubpath()
            }
        }
    }
}
