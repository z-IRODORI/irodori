//
//  TryOnLoadingDesigns.swift
//  irodori
//
//  試着ローディング演出の候補比較 (トグル同居の1ファイル)。
//  - 案A: タイプライター吹き出し + サムネイル軌道 (本番 TryOnLoadingView をそのまま表示)
//  - 案B: ステージ進行チップ (コーデを確認 → 着せ替え中 → 仕上げ) + Haptic 連鎖
//  - 案C: ミニマル (パルス同心円 + 人型シルエットへアイテムが吸い込まれる)
//
//  確認方法: #Preview「3案 比較」で segmented 切替。
//  実APIでの通し確認は TryOnView.swift の #Preview「実API (要顔登録)」を使う。
//  採用案が決まったら本番 TryOnLoadingView を差し替え、来歴コメントを残すこと。
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

// MARK: - 案B: ステージ進行チップ + Haptic

private struct TryOnLoadingDesignB: View {
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
                                .tint(stage == index ? .white : .black)
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

// MARK: - 案C: ミニマル (シルエット吸い込み)

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

                    // アイテムサムネがシルエットへ吸い込まれてフェード
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
    @State private var selected = 0
    @State private var restartKey = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("案", selection: $selected) {
                Text("A 吹き出し").tag(0)
                Text("B ステージ").tag(1)
                Text("C ミニマル").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            Group {
                switch selected {
                case 0:
                    TryOnLoadingView(
                        faceImage: nil,
                        thumbnailURLs: TryOnLoadingSandbox.thumbnailURLs,
                        onCancel: { restartKey += 1 })
                case 1:
                    TryOnLoadingDesignB(
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
