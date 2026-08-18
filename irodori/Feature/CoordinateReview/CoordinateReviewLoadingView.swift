//
//  CoordinateReviewLoadingView.swift
//  irodori
//
//  コーデレビュー作成中のローディング画面 (Sandbox 案A の本実装).
//  撮影した全身画像の上をスキャンラインが走り、オンデバイスセグメンテーションの
//  完了 (topsImage / bottomsImage 確定) を受けて、実際の検出位置にバウンディング
//  ボックスが出る → 切り出した服が写真から抜き出されて下のトレイへ飛んでいく。
//  その後は API 応答 (8〜10 秒) まで「AIレビュー生成中」を表示する。
//

import SwiftUI

struct CoordinateReviewLoadingView: View {
    /// 撮影した全身画像
    let coordinateImage: UIImage
    /// segment() が切り出したトップス / ボトムス (完了までは nil)
    let topsImage: UIImage?
    let bottomsImage: UIImage?
    /// 検出位置 (正規化座標)。取れなかった場合は既定位置で演出する
    let topsRect: CGRect?
    let bottomsRect: CGRect?

    private enum Stage: Int, Comparable {
        case scanning       // セグメンテーション実行中
        case tops           // トップス検出の発表
        case bottoms        // ボトムス検出の発表
        case analyzing      // AI レビュー生成中 (API 待ち)

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @State private var stage: Stage = .scanning
    @State private var topsLanded = false     // 切り出し画像がトレイに到着したか
    @State private var bottomsLanded = false
    @Namespace private var flyNamespace

    private let brandPink = Color(red: 1.0, green: 0.27, blue: 0.42)
    private let brandOrange = Color(red: 1.0, green: 0.45, blue: 0.30)
    private var brandGradient: LinearGradient {
        LinearGradient(colors: [brandPink, brandOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private let popSpring = Animation.spring(response: 0.4, dampingFraction: 0.7)
    private let flightSpring = Animation.spring(response: 0.55, dampingFraction: 0.78)

    /// セグメンテーション完了 (tops / bottoms は同時に確定する)
    private var detectionReady: Bool { topsImage != nil && bottomsImage != nil }

    /// 検出ボックスが取れなかったときの既定位置
    private var resolvedTopsRect: CGRect {
        topsRect ?? CGRect(x: 0.28, y: 0.18, width: 0.44, height: 0.27)
    }
    private var resolvedBottomsRect: CGRect {
        bottomsRect ?? CGRect(x: 0.30, y: 0.46, width: 0.40, height: 0.42)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("コーデを分析中...")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                // v2 (アイテム画像生成あり) は legacy より時間がかかる
                Text(AnalysisEngine.current == .v2 ? "作成に20〜30秒ほど時間がかかります" : "作成に8〜10秒ほど時間がかかります")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.black.opacity(0.4))
            }
            .padding(.top, 24)

            photoWithOverlay
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                detectedItemSlot(
                    title: "トップス",
                    image: topsLanded ? topsImage : nil,
                    matchedID: "tops"
                )
                detectedItemSlot(
                    title: "ボトムス",
                    image: bottomsLanded ? bottomsImage : nil,
                    matchedID: "bottoms"
                )
            }
            .padding(.horizontal, 40)

            stepBar
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .task(id: detectionReady) { await runDetectionSequence() }
    }

    // MARK: - 検出 → 抜き出し → トレイ着地 の進行
    // 実データは segment() 完了時に tops / bottoms が同時に確定するため、
    // 演出としてトップス → ボトムスの順に時間差で発表する

    private func runDetectionSequence() async {
        guard detectionReady, stage == .scanning else { return }

        withAnimation(popSpring) { stage = .tops }
        try? await Task.sleep(for: .seconds(0.75))
        guard !Task.isCancelled else { return }
        withAnimation(flightSpring) { topsLanded = true }
        Haptic.impact(.soft)

        try? await Task.sleep(for: .seconds(1.0))
        guard !Task.isCancelled else { return }
        withAnimation(popSpring) { stage = .bottoms }
        try? await Task.sleep(for: .seconds(0.75))
        guard !Task.isCancelled else { return }
        withAnimation(flightSpring) { bottomsLanded = true }
        Haptic.impact(.soft)

        try? await Task.sleep(for: .seconds(0.9))
        guard !Task.isCancelled else { return }
        withAnimation(popSpring) { stage = .analyzing }
    }

    // MARK: - 写真 + 検出オーバーレイ

    private var photoWithOverlay: some View {
        Image(uiImage: coordinateImage)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        gridOverlay(size: size)
                        scanLine(size: size)
                        // 抜き出し前の切り出し画像 (飛翔の出発点)。
                        // 検出ボックス + ラベルより先に敷き、ラベルを前面に出す。
                        if stage >= .tops, !topsLanded, let topsImage {
                            extractedItemOverlay(
                                image: topsImage,
                                normalizedRect: resolvedTopsRect,
                                containerSize: size,
                                matchedID: "tops"
                            )
                        }
                        if stage >= .bottoms, !bottomsLanded, let bottomsImage {
                            extractedItemOverlay(
                                image: bottomsImage,
                                normalizedRect: resolvedBottomsRect,
                                containerSize: size,
                                matchedID: "bottoms"
                            )
                        }
                        // 検出ボックス + ラベルは最前面 (切り出し画像=四角窓 の上)
                        if stage >= .tops {
                            detectionBox(
                                label: "トップス",
                                normalizedRect: resolvedTopsRect,
                                containerSize: size,
                                isExtracted: topsLanded
                            )
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
                        }
                        if stage >= .bottoms {
                            detectionBox(
                                label: "ボトムス",
                                normalizedRect: resolvedBottomsRect,
                                containerSize: size,
                                isExtracted: bottomsLanded
                            )
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
                        }
                        if stage == .analyzing {
                            analyzingChip
                                .position(x: size.width / 2, y: size.height / 2)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.black.opacity(0.08), lineWidth: 1)
            }
    }

    /// 検出直後にボックス位置へ重ねる切り出し画像。
    /// landed になるとここから消え、トレイ側の matchedGeometryEffect へ縮小しながら飛んでいく。
    private func extractedItemOverlay(
        image: UIImage,
        normalizedRect: CGRect,
        containerSize: CGSize,
        matchedID: String
    ) -> some View {
        let frame = boxFrame(normalizedRect, in: containerSize)
        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: frame.width, height: frame.height)
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            .matchedGeometryEffect(id: matchedID, in: flyNamespace)
            .position(x: frame.midX, y: frame.midY)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 1.12).combined(with: .opacity),
                    removal: .opacity
                )
            )
            .allowsHitTesting(false)
    }

    private func gridOverlay(size: CGSize) -> some View {
        Canvas { context, _ in
            let step: CGFloat = 28
            var path = Path()
            var x: CGFloat = step
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = step
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private func scanLine(size: CGSize) -> some View {
        // 経過時間から位置を算出することで、onAppear / GeometryReader のタイミングに
        // 依存せず確実に動かす (上→下→上 の往復スキャン)。
        let period: Double = 2.4
        return TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: period) / period   // 0..1
            let tri = phase < 0.5 ? phase * 2 : (2 - phase * 2)              // 0→1→0
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0),
                            .black.opacity(0.12),
                            .black.opacity(0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: size.width, height: 70)
                .overlay(alignment: .bottom) {
                    // 黒のスキャン線 (IRODORI らしいミニマル)。暗い服の上でも視認できるよう
                    // 白の弱いグロー + 黒のソフトシャドウを重ねる。
                    Rectangle()
                        .fill(.black)
                        .frame(height: 1.5)
                        .shadow(color: .white.opacity(0.6), radius: 2)
                        .shadow(color: .black.opacity(0.25), radius: 5)
                }
                .position(x: size.width / 2, y: CGFloat(tri) * size.height)
        }
        .opacity(stage == .analyzing ? 0.25 : 1)
        .allowsHitTesting(false)
    }

    private var analyzingChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
            Text("AIレビュー生成中...")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(brandGradient)
        .clipShape(Capsule())
        .shadow(color: brandPink.opacity(0.5), radius: 10)
    }

    // MARK: - 検出ボックス (コーナーブラケット + ラベル)

    private func boxFrame(_ normalizedRect: CGRect, in containerSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedRect.minX * containerSize.width,
            y: normalizedRect.minY * containerSize.height,
            width: normalizedRect.width * containerSize.width,
            height: normalizedRect.height * containerSize.height
        )
    }

    private func detectionBox(
        label: String,
        normalizedRect: CGRect,
        containerSize: CGSize,
        isExtracted: Bool
    ) -> some View {
        let frame = boxFrame(normalizedRect, in: containerSize)
        return CornerBrackets()
            .stroke(brandPink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .shadow(color: brandPink.opacity(0.6), radius: 4)
            .background {
                // 抜き取られた後は内側を暗くして「抽出済み」感を出す
                if isExtracted {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.black.opacity(0.30))
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(brandPink)
                .clipShape(Capsule())
                .offset(x: -4, y: -12)
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
    }

    // MARK: - 検出済みアイテムトレイ

    private func detectedItemSlot(title: String, image: UIImage?, matchedID: String) -> some View {
        HStack(spacing: 10) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .matchedGeometryEffect(id: matchedID, in: flyNamespace)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(.black.opacity(0.25))
                        .overlay {
                            ProgressView()
                                .tint(.black.opacity(0.4))
                        }
                        .frame(width: 48, height: 48)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.9))
                if image != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("検出済み")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(brandPink)
                } else {
                    Text("検出中...")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.black.opacity(0.35))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        // clipShape だと写真から飛んでくる画像がカード境界で切られるため background(_:in:) を使う
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - ステップインジケータ (スキャン → 検出 → AIレビュー)

    private var stepBar: some View {
        HStack(spacing: 8) {
            stepChip(label: "スキャン", isDone: stage >= .tops, isActive: stage == .scanning)
            stepConnector(isDone: stage >= .tops)
            stepChip(label: "アイテム検出", isDone: stage >= .analyzing, isActive: stage == .tops || stage == .bottoms)
            stepConnector(isDone: stage >= .analyzing)
            stepChip(label: "AIレビュー", isDone: false, isActive: stage == .analyzing)
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
        .foregroundStyle(isDone || isActive ? brandPink : .black.opacity(0.35))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isDone || isActive ? brandPink.opacity(0.12) : .black.opacity(0.06))
        .clipShape(Capsule())
    }

    private func stepConnector(isDone: Bool) -> some View {
        Rectangle()
            .fill(isDone ? brandPink.opacity(0.6) : .black.opacity(0.15))
            .frame(width: 14, height: 2)
    }
}

// MARK: - コーナーブラケット

private struct CornerBrackets: Shape {
    var cornerLength: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let l = min(cornerLength, rect.width / 3, rect.height / 3)
        return Path { p in
            // 左上
            p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
            // 右上
            p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
            // 右下
            p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
            // 左下
            p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        }
    }
}

#Preview("検出前 (スキャン中)") {
    CoordinateReviewLoadingView(
        coordinateImage: UIImage(resource: .coordinate2),
        topsImage: nil,
        bottomsImage: nil,
        topsRect: nil,
        bottomsRect: nil
    )
}

#Preview("検出後 (発表シーケンス)") {
    CoordinateReviewLoadingView(
        coordinateImage: UIImage(resource: .coordinate2),
        topsImage: UIImage(resource: .tops1),
        bottomsImage: UIImage(resource: .bottoms1),
        topsRect: CGRect(x: 0.29, y: 0.19, width: 0.38, height: 0.24),
        bottomsRect: CGRect(x: 0.34, y: 0.38, width: 0.37, height: 0.55)
    )
}
