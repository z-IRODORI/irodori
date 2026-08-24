//
//  TryOnLoadingDesigns.swift
//  irodori
//
//  試着ローディング演出の候補比較 (トグル同居の1ファイル)。
//  2026-08-25 に案B (ステージ進行チップ + Haptic 連鎖) を採用し、
//  本番 Feature/TryOn/TryOnLoadingView.swift として部品化済み。
//  - 案A: タイプライター吹き出し + サムネイル軌道 (未採用・このファイルに保存)
//  - 案B: ステージ進行チップ (採用 → 本番 TryOnLoadingView をそのまま表示)
//  - 案C: ミニマル (パルス同心円 + シルエット吸い込み。未採用・このファイルに保存)
//
//  確認方法: #Preview「3案 比較」で segmented 切替。
//  実APIでの通し確認は TryOnView.swift の #Preview「実API (要顔登録)」を使う。
//

import SwiftUI
import Kingfisher

// MARK: - 共通モックデータ

enum TryOnLoadingSandbox {
    static let thumbnailURLs = [
        "https://i.pinimg.com/736x/a6/5a/50/a65a50686f1c10f5c98f2bedd434bf1e.jpg",
        "https://i.pinimg.com/736x/82/77/a9/8277a98095eda2e3b1435905296dd056.jpg",
        "https://i.pinimg.com/736x/52/33/63/523363348ca1f3d4fc5139e8041be082.jpg",
    ]
}

// MARK: - 案A: タイプライター吹き出し + サムネイル軌道 (未採用)

private struct TryOnLoadingDesignA: View {
    let faceImage: UIImage?
    let thumbnailURLs: [String]
    let onCancel: () -> Void

    @State private var messageIndex = 0
    @State private var typedText = ""
    @State private var pulse = false

    private let messages = [
        "コーデを準備しています…",
        "あなたに合わせて試着中…",
        "細部を仕上げています…",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            orbitStage
                .frame(height: 260)

            speechBubble
                .padding(.top, 28)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                Haptic.impact(.soft)
                onCancel()
            } label: {
                Text("キャンセル")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.08))
        .task(id: messageIndex) { await typeCurrentMessage() }
        .onAppear { pulse = true }
    }

    private var orbitStage: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 1.5)
                        .frame(width: 130 + CGFloat(index) * 46)
                        .scaleEffect(pulse ? 1.06 : 0.96)
                        .animation(
                            .easeInOut(duration: 1.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.25),
                            value: pulse)
                }

                faceCircle

                ForEach(Array(thumbnailURLs.prefix(6).enumerated()), id: \.offset) { index, urlString in
                    let count = min(thumbnailURLs.count, 6)
                    let angle = time * 0.55 + (Double(index) / Double(max(count, 1))) * 2 * .pi
                    orbitThumb(urlString)
                        .offset(x: cos(angle) * 120, y: sin(angle) * 58)
                }
            }
        }
    }

    private var faceCircle: some View {
        Group {
            if let faceImage {
                Image(uiImage: faceImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .padding(16)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    private func orbitThumb(_ urlString: String) -> some View {
        KFImage(URL(string: urlString))
            .resizable()
            .scaledToFill()
            .frame(width: 46, height: 46)
            .background(.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private var speechBubble: some View {
        Text(typedText.isEmpty ? " " : typedText)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.black.opacity(0.75))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func typeCurrentMessage() async {
        let message = messages[messageIndex % messages.count]
        typedText = ""
        for character in message {
            guard !Task.isCancelled else { return }
            typedText.append(character)
            try? await Task.sleep(nanoseconds: 38_000_000)
        }
        try? await Task.sleep(nanoseconds: 2_400_000_000)
        guard !Task.isCancelled else { return }
        messageIndex += 1
    }
}

// MARK: - 案C: ミニマル (シルエット吸い込み・未採用)

private struct TryOnLoadingDesignC: View {
    let thumbnailURLs: [String]
    let onCancel: () -> Void

    @State private var pulse = false
    @State private var dots = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.black.opacity(0.07), lineWidth: 1.5)
                            .frame(width: 150 + CGFloat(index) * 55)
                            .scaleEffect(pulse ? 1.05 : 0.95)
                            .animation(
                                .easeInOut(duration: 1.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.3),
                                value: pulse)
                    }

                    Circle()
                        .fill(.white)
                        .frame(width: 140, height: 140)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                    Image(systemName: "figure.stand")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(Color.black.opacity(0.55))

                    ForEach(Array(thumbnailURLs.prefix(4).enumerated()), id: \.offset) { index, url in
                        let cycle = 3.2
                        let phase = (time / cycle + Double(index) / Double(max(thumbnailURLs.count, 1)))
                            .truncatingRemainder(dividingBy: 1)
                        let distance = 150 * (1 - phase)
                        let angle = Double(index) * 1.7
                        KFImage(URL(string: url))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .offset(x: cos(angle) * distance, y: sin(angle) * distance * 0.55)
                            .opacity(phase < 0.85 ? 0.9 : (1 - phase) / 0.15 * 0.9)
                            .scaleEffect(0.6 + 0.4 * (1 - phase))
                    }
                }
            }
            .frame(height: 300)

            Text("試着イメージを生成中" + String(repeating: "・", count: dots + 1))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.top, 20)

            Spacer()

            Button {
                Haptic.impact(.soft)
                onCancel()
            } label: {
                Text("キャンセル")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.08))
        .onAppear { pulse = true }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                dots = (dots + 1) % 3
            }
        }
    }
}

// MARK: - 比較ビュー

struct TryOnLoadingDesignsCompare: View {
    @State private var selected = 1   // 既定は採用済みの案B
    @State private var restartKey = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("案", selection: $selected) {
                Text("A 吹き出し").tag(0)
                Text("B ステージ (採用)").tag(1)
                Text("C ミニマル").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            Group {
                switch selected {
                case 0:
                    TryOnLoadingDesignA(
                        faceImage: nil,
                        thumbnailURLs: TryOnLoadingSandbox.thumbnailURLs,
                        onCancel: { restartKey += 1 })
                case 1:
                    // 採用済み: 本番部品をそのまま表示
                    TryOnLoadingView(
                        faceImage: nil,
                        thumbnailURLs: TryOnLoadingSandbox.thumbnailURLs,
                        onCancel: { restartKey += 1 })
                default:
                    TryOnLoadingDesignC(
                        thumbnailURLs: TryOnLoadingSandbox.thumbnailURLs,
                        onCancel: { restartKey += 1 })
                }
            }
            .id("\(selected)-\(restartKey)")  // 切替・キャンセルで演出を最初から再生
        }
    }
}

#Preview("3案 比較") {
    TryOnLoadingDesignsCompare()
}

#Preview("Mock 通し (2秒→結果)") {
    TryOnView(
        source: .snap(
            id: "sandbox-pool",
            imageURL: TryOnLoadingSandbox.thumbnailURLs[0],
            labels: ["トップス: 白シャツ"]),
        client: MockTryOnClient(),
        faceDataOverride: Data([0xFF]))
}

#Preview("Mock 遅延 (15秒)") {
    TryOnView(
        source: .snap(
            id: "sandbox-pool-slow",
            imageURL: TryOnLoadingSandbox.thumbnailURLs[0],
            labels: ["トップス: 白シャツ"]),
        client: MockTryOnClient(delaySeconds: 15),
        faceDataOverride: Data([0xFF]))
}
