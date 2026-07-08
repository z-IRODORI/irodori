//
//  LoadingDesignA.swift
//  irodori - Sandbox
//
//  案A: AI 検出スキャン (本命).
//  撮影した全身画像の上をスキャンラインが走り、トップス / ボトムスが
//  バウンディングボックスで「検出」されて下のトレイに切り出し画像が溜まる。
//  本実装では segment() 完了時に本物の topsUIImage / bottomsUIImage を流し込める。
//

import SwiftUI

struct LoadingDesignA: View {
    @State private var phase: LoadingDemoPhase = .scanning
    @State private var scanY: CGFloat = 0   // 0...1 (写真内の縦位置)

    private let darkBackground = Color(red: 0.08, green: 0.07, blue: 0.10)

    var body: some View {
        VStack(spacing: 20) {
            LoadingDemoHeader(
                title: "コーデを分析中...",
                subtitle: "AIが全身写真からアイテムを検出しています",
                foreground: .white
            )
            .padding(.top, 24)

            photoWithOverlay
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                DetectedItemSlot(
                    title: "トップス",
                    image: phase >= .topsDetected ? LoadingSandbox.sampleTopsImage : nil
                )
                DetectedItemSlot(
                    title: "ボトムス",
                    image: phase >= .bottomsDetected ? LoadingSandbox.sampleBottomsImage : nil
                )
            }
            .padding(.horizontal, 40)

            LoadingDemoStepBar(phase: phase, foreground: .white)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(darkBackground.ignoresSafeArea())
        .loadingDemoPhaseDriver($phase)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scanY = 1
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
                                containerSize: size
                            )
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
                        }
                        if phase >= .bottomsDetected {
                            DetectionBox(
                                label: "ボトムス",
                                normalizedRect: LoadingSandbox.bottomsRect,
                                containerSize: size
                            )
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
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
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            }
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

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(.white.opacity(0.3))
                        .overlay {
                            ProgressView()
                                .tint(.white.opacity(0.5))
                        }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
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
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("A: AI検出スキャン") {
    LoadingDesignA()
}
