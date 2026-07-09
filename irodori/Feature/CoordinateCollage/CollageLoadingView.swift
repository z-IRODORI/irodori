//
//  CollageLoadingView.swift
//  irodori
//
//  コーデコラージュ生成中のローディング画面 (Sandbox 案B/C のイメージ).
//  相棒が中央で呼吸しながら、選択したコーデ写真が周りを楕円軌道でまわり、
//  タイプライター風の吹き出しで進捗コメントを話し続ける。
//  相棒の後光はユーザーが選んだコラージュ背景色。
//

import SwiftUI
import Kingfisher

struct CollageLoadingView: View {
    /// 生成に使う画像のサムネイル (登録コーデ = URL / 写真フォルダ = UIImage)
    enum Thumbnail: Identifiable {
        case local(id: Int, image: UIImage)
        case remote(id: String, url: URL)

        var id: String {
            switch self {
            case .local(let id, _): "local-\(id)"
            case .remote(let id, _): "remote-\(id)"
            }
        }
    }

    let thumbnails: [Thumbnail]
    /// ユーザーが選んだコラージュ背景色 (相棒の後光に使う)
    let accentColor: Color
    let onCancel: () -> Void

    @State private var breathe = false
    @State private var visibleText = ""
    @State private var messageIndex = 0

    private let messages: [String] = [
        "どの写真から並べようかな〜",
        "人物をきれいに切り抜いてるよ ✂️",
        "えらんだ背景色に合わせて配置を考え中…",
        "もうすぐできるよ！たのしみにしてて",
    ]

    private let orbitRadiusX: CGFloat = 130
    private let orbitRadiusY: CGFloat = 38
    /// 1周にかける秒数
    private let orbitPeriod: TimeInterval = 16

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            speechCard
                .padding(.horizontal, 40)

            orbitStage
                .frame(height: 250)
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text("コラージュを作成しています")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("人物を切り抜いて1枚に合成しています")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 8)

            Spacer()

            Button {
                onCancel()
            } label: {
                Text("キャンセル")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(Color.black.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .task(id: messageIndex) { await typeCurrentMessage() }
    }

    // MARK: - 吹き出し (タイプライター)

    private var speechCard: some View {
        VStack(spacing: -1) {
            HStack(alignment: .top, spacing: 0) {
                Text(visibleText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                Text("|")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.5))
                    .opacity(breathe ? 1 : 0.15)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44, alignment: .topLeading)
            .padding(14)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            BubbleTail()
                .fill(Color.gray.opacity(0.08))
                .frame(width: 16, height: 9)
        }
    }

    private func typeCurrentMessage() async {
        let message = messages[messageIndex]
        visibleText = ""
        for character in message {
            visibleText.append(character)
            try? await Task.sleep(for: .milliseconds(38))
            if Task.isCancelled { return }
        }
        try? await Task.sleep(for: .seconds(2.4))
        if Task.isCancelled { return }
        messageIndex = (messageIndex + 1) % messages.count
    }

    // MARK: - 相棒 + 写真の軌道

    private var orbitStage: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                orbitCards(time: time, front: false)
                buddy
                orbitCards(time: time, front: true)
            }
        }
    }

    private var buddy: some View {
        ZStack {
            Circle()
                .fill(accentColor)
                .frame(width: 120, height: 120)
                .opacity(0.18)
                .scaleEffect(breathe ? 1.12 : 0.94)
            PartnerIconImage(size: 96)
                .overlay {
                    Circle().stroke(.white, lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                .scaleEffect(breathe ? 1.03 : 0.98)
                .rotationEffect(.degrees(breathe ? 2 : -2))
        }
    }

    /// 楕円軌道をまわる写真カード。front で手前 (下半分) と奥 (上半分) を描き分ける
    private func orbitCards(time: TimeInterval, front: Bool) -> some View {
        ForEach(Array(thumbnails.enumerated()), id: \.element.id) { index, thumbnail in
            orbitCard(thumbnail, index: index, count: thumbnails.count, time: time, front: front)
        }
    }

    @ViewBuilder
    private func orbitCard(_ thumbnail: Thumbnail, index: Int, count: Int, time: TimeInterval, front: Bool) -> some View {
        let angle: Double = time * (2 * .pi / orbitPeriod) + Double(index) * (2 * .pi / Double(max(count, 1)))
        let depth: Double = sin(angle)   // -1 (奥) ... +1 (手前)
        if (depth >= 0) == front {
            thumbnailImage(thumbnail)
                .frame(width: 56, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.black.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                .scaleEffect(0.72 + 0.28 * (depth + 1) / 2)
                .opacity(front ? 1.0 : 0.5)
                .offset(
                    x: CGFloat(cos(angle)) * orbitRadiusX,
                    y: CGFloat(depth) * orbitRadiusY
                )
        }
    }

    @ViewBuilder
    private func thumbnailImage(_ thumbnail: Thumbnail) -> some View {
        switch thumbnail {
        case .local(_, let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        case .remote(_, let url):
            KFImage(url)
                .resizable()
                .placeholder { Color.gray.opacity(0.12) }
                .scaledToFill()
        }
    }
}

// MARK: - 吹き出しの下向きしっぽ

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

#Preview("コラージュ生成中") {
    CollageLoadingView(
        thumbnails: [
            .local(id: 0, image: UIImage(resource: .coordinate1)),
            .local(id: 1, image: UIImage(resource: .coordinate2)),
            .local(id: 2, image: UIImage(resource: .coordinate3)),
            .local(id: 3, image: UIImage(resource: .coordinate4)),
            .local(id: 4, image: UIImage(resource: .coordinate5)),
        ],
        accentColor: Color(red: 1.0, green: 140.0 / 255.0, blue: 66.0 / 255.0),
        onCancel: {}
    )
}
