//
//  LoadingDesignA.swift
//  irodori - Sandbox
//
//  案A: AI 検出スキャン (本命).
//  撮影した全身画像の上をスキャンラインが走り、トップス / ボトムスが
//  バウンディングボックスで「検出」→ 切り出し画像が写真から抜き出されて
//  下のトレイへ飛んでいく (matchedGeometryEffect)。
//  本実装では segment() 完了時に本物の topsUIImage / bottomsUIImage を流し込める。
//

import SwiftUI

struct LoadingDesignA: View {
    @State private var phase: LoadingDemoPhase = .scanning
    @State private var scanY: CGFloat = 0        // 0...1 (写真内の縦位置)
    @State private var topsLanded = false        // 切り出し画像がトレイに到着したか
    @State private var bottomsLanded = false
    @Namespace private var flyNamespace

    // ダーク版に戻すときは darkBackground を Color(red: 0.08, green: 0.07, blue: 0.10) にして isDarkTheme = true にする
    private let darkBackground = Color.clear
    private let isDarkTheme = false

    /// 写真 → トレイへの飛翔アニメーション
    private let flightSpring = Animation.spring(response: 0.55, dampingFraction: 0.78)

    private var textPrimary: Color { isDarkTheme ? .white : .black }

    var body: some View {
        VStack(spacing: 20) {
            LoadingDemoHeader(
                title: "コーデを分析中...",
                subtitle: "AIが全身写真からアイテムを検出しています",
                foreground: textPrimary
            )
            .padding(.top, 24)

            photoWithOverlay
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                DetectedItemSlot(
                    title: "トップス",
                    image: topsLanded ? LoadingSandbox.sampleTopsImage : nil,
                    matchedID: "tops",
                    namespace: flyNamespace,
                    isDarkTheme: isDarkTheme
                )
                DetectedItemSlot(
                    title: "ボトムス",
                    image: bottomsLanded ? LoadingSandbox.sampleBottomsImage : nil,
                    matchedID: "bottoms",
                    namespace: flyNamespace,
                    isDarkTheme: isDarkTheme
                )
            }
            .padding(.horizontal, 40)

            LoadingDemoStepBar(phase: phase, foreground: textPrimary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(darkBackground.ignoresSafeArea())
        .loadingDemoPhaseDriver($phase)
        .task(id: phase) { await runExtractionSequence() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scanY = 1
            }
        }
    }

    // MARK: - 検出 → 抜き出し → トレイ着地 の進行

    private func runExtractionSequence() async {
        switch phase {
        case .scanning:
            // ループ先頭: アニメーションなしで初期化
            topsLanded = false
            bottomsLanded = false
        case .topsDetected:
            try? await Task.sleep(for: .seconds(0.75))
            guard !Task.isCancelled else { return }
            withAnimation(flightSpring) { topsLanded = true }
            try? await Task.sleep(for: .seconds(0.4))
            Haptic.impact(.soft)
        case .bottomsDetected:
            try? await Task.sleep(for: .seconds(0.75))
            guard !Task.isCancelled else { return }
            withAnimation(flightSpring) { bottomsLanded = true }
            try? await Task.sleep(for: .seconds(0.4))
            Haptic.impact(.soft)
        case .analyzing:
            // 飛翔が終わっていなければ回収しておく
            withAnimation(flightSpring) {
                topsLanded = true
                bottomsLanded = true
            }
        }
    }

    // MARK: - 写真 + 検出オーバーレイ

    private var photoWithOverlay: some View {
        Image(uiImage: LoadingSandbox.sampleImage)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        gridOverlay(size: size)
                        scanLine(size: size)
                        if phase >= .topsDetected {
                            DetectionBox(
                                label: "トップス",
                                normalizedRect: LoadingSandbox.topsRect,
                                containerSize: size,
                                isExtracted: topsLanded
                            )
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
                        }
                        if phase >= .bottomsDetected {
                            DetectionBox(
                                label: "ボトムス",
                                normalizedRect: LoadingSandbox.bottomsRect,
                                containerSize: size,
                                isExtracted: bottomsLanded
                            )
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
                        }
                        // 抜き出し前の切り出し画像 (飛翔の出発点)
                        if phase >= .topsDetected, !topsLanded {
                            extractedItemOverlay(
                                image: LoadingSandbox.sampleTopsImage,
                                normalizedRect: LoadingSandbox.topsRect,
                                containerSize: size,
                                matchedID: "tops"
                            )
                        }
                        if phase >= .bottomsDetected, !bottomsLanded {
                            extractedItemOverlay(
                                image: LoadingSandbox.sampleBottomsImage,
                                normalizedRect: LoadingSandbox.bottomsRect,
                                containerSize: size,
                                matchedID: "bottoms"
                            )
                        }
                        if phase == .analyzing {
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
                    .stroke(isDarkTheme ? .white.opacity(0.15) : .black.opacity(0.08), lineWidth: 1)
            }
    }

    /// 検出直後にボックス位置へ重ねる切り出し画像。
    /// topsLanded / bottomsLanded が true になるとここから消え、
    /// トレイ側の matchedGeometryEffect へ縮小しながら飛んでいく。
    private func extractedItemOverlay(
        image: UIImage,
        normalizedRect: CGRect,
        containerSize: CGSize,
        matchedID: String
    ) -> some View {
        let frame = CGRect(
            x: normalizedRect.minX * containerSize.width,
            y: normalizedRect.minY * containerSize.height,
            width: normalizedRect.width * containerSize.width,
            height: normalizedRect.height * containerSize.height
        )
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: frame.width, height: frame.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white, lineWidth: 1.5)
            }
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
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        LoadingSandbox.brandPink.opacity(0),
                        LoadingSandbox.brandPink.opacity(0.35),
                        LoadingSandbox.brandPink.opacity(0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(height: 70)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(LoadingSandbox.brandGradient)
                    .frame(height: 2)
                    .shadow(color: LoadingSandbox.brandPink, radius: 6)
            }
            .position(x: size.width / 2, y: scanY * size.height)
            .opacity(phase == .analyzing ? 0.25 : 1)
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
        .background(LoadingSandbox.brandGradient)
        .clipShape(Capsule())
        .shadow(color: LoadingSandbox.brandPink.opacity(0.5), radius: 10)
    }
}

// MARK: - 検出ボックス (コーナーブラケット + ラベル)

private struct DetectionBox: View {
    let label: String
    let normalizedRect: CGRect
    let containerSize: CGSize
    /// 切り出し画像が抜き取られた後は内側を暗くして「抽出済み」感を出す
    var isExtracted: Bool = false

    var body: some View {
        let frame = CGRect(
            x: normalizedRect.minX * containerSize.width,
            y: normalizedRect.minY * containerSize.height,
            width: normalizedRect.width * containerSize.width,
            height: normalizedRect.height * containerSize.height
        )
        CornerBrackets()
            .stroke(LoadingSandbox.brandPink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .shadow(color: LoadingSandbox.brandPink.opacity(0.6), radius: 4)
            .background {
                if isExtracted {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.black.opacity(0.05))
//                        .fill(.clear)
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
                .background(LoadingSandbox.brandPink)
                .clipShape(Capsule())
                .offset(x: -4, y: -12)
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
    }
}

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

// MARK: - 検出済みアイテムトレイ

private struct DetectedItemSlot: View {
    let title: String
    let image: UIImage?
    let matchedID: String
    let namespace: Namespace.ID
    let isDarkTheme: Bool

    private var foreground: Color { isDarkTheme ? .white : .black }
    private var cardFill: Color { isDarkTheme ? .white.opacity(0.08) : .gray.opacity(0.08) }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .matchedGeometryEffect(id: matchedID, in: namespace)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(foreground.opacity(0.3))
                        .overlay {
                            ProgressView()
                                .tint(foreground.opacity(0.5))
                        }
                        .frame(width: 48, height: 48)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.9))
                if image != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("検出済み")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(LoadingSandbox.brandPink)
                } else {
                    Text("検出中...")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(foreground.opacity(0.4))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        // clipShape だと写真から飛んでくる画像がカード境界で切られるため background(_:in:) を使う
        .background(cardFill, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("A: AI検出スキャン") {
    LoadingDesignA()
}
