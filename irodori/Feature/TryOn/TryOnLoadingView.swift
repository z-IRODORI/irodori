//
//  TryOnLoadingView.swift
//  irodori
//
//  試着生成中のローディング演出。
//  Feature/Sandbox/TryOnLoadingDesigns.swift の3案比較から案B
//  (ステージ進行チップ + Haptic 連鎖) を採用して本番部品化 (2026-08-25)。
//  未採用の案A (タイプライター吹き出し+軌道) / 案C (ミニマル) は Sandbox に残している。
//

import SwiftUI
import Kingfisher

struct TryOnLoadingView: View {
    let faceImage: UIImage?
    let thumbnailURLs: [String]
    let onCancel: () -> Void

    @State private var stage = 0
    private let stages = ["コーデを確認", "着せ替え中", "仕上げ"]
    private let captions = [
        "選んだアイテムを確認しています",
        "あなたの写真にコーデを合わせています",
        "光と質感を整えています",
    ]

    var body: some View {
        VStack(spacing: 0) {
            stepBar
                .padding(.top, 28)
                .padding(.horizontal, 32)

            Spacer()

            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 150, height: 150)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                if let faceImage {
                    Image(uiImage: faceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 130)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.gray.opacity(0.35))
                }
            }

            HStack(spacing: 10) {
                ForEach(Array(thumbnailURLs.prefix(4).enumerated()), id: \.offset) { index, url in
                    KFImage(URL(string: url))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                        .opacity(stage >= 1 || index == 0 ? 1 : 0.25)
                        .scaleEffect(stage >= 1 ? 1 : 0.85)
                }
            }
            .padding(.top, 24)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: stage)

            Text(captions[min(stage, captions.count - 1)])
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 18)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: stage)

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
        .task {
            // 生成は 4〜15 秒程度。4 秒ごとにステージを進め、最後のステージで待つ
            while stage < stages.count - 1 {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { stage += 1 }
                Haptic.impact(.soft)
            }
        }
    }

    private var stepBar: some View {
        HStack(spacing: 6) {
            ForEach(stages.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        if stage > index {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                        } else if stage == index {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        }
                        Text(stages[index])
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(stage >= index ? .white : Color.gray.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(stage >= index ? Color.black : Color.gray.opacity(0.12))
                    .clipShape(Capsule())

                    if index < stages.count - 1 {
                        Rectangle()
                            .fill(stage > index ? Color.black : Color.gray.opacity(0.25))
                            .frame(height: 1.5)
                            .frame(maxWidth: 20)
                    }
                }
            }
        }
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
