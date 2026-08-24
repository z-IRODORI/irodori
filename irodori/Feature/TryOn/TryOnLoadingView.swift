//
//  TryOnLoadingView.swift
//  irodori
//
//  試着生成中のローディング演出 (案A: タイプライター吹き出し + サムネイル軌道)。
//  CollageLoadingView の設計 (段階メッセージ + タイプライター + 軌道サムネ) を踏襲。
//  案の比較は Feature/Sandbox/TryOnLoadingDesigns.swift を参照。
//

import SwiftUI
import Kingfisher

struct TryOnLoadingView: View {
    let faceImage: UIImage?
    let thumbnailURLs: [String]
    let onCancel: () -> Void

    @State private var messageIndex = 0
    @State private var typedText = ""
    @State private var pulse = false

    /// 生成は 4〜15 秒程度。8 秒周期で言葉を進めて「進んでいる感」を保つ
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

    // MARK: - 中央の顔 + 軌道サムネ

    private var orbitStage: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                // パルスする同心円
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

                // アイテム/スナップのサムネが楕円軌道を回る
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

    // MARK: - タイプライター吹き出し

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

#Preview("ローディング (サムネあり)") {
    TryOnLoadingView(
        faceImage: nil,
        thumbnailURLs: [
            "https://i.pinimg.com/736x/a6/5a/50/a65a50686f1c10f5c98f2bedd434bf1e.jpg",
            "https://i.pinimg.com/736x/82/77/a9/8277a98095eda2e3b1435905296dd056.jpg",
            "https://i.pinimg.com/736x/52/33/63/523363348ca1f3d4fc5139e8041be082.jpg",
        ],
        onCancel: {})
}
