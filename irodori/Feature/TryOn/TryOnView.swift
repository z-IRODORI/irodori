//
//  TryOnView.swift
//  irodori
//
//  試着画面 (fullScreenCover — コーデ詳細と同じく画像の視認性を優先して全画面)。
//  loading → TryOnLoadingView / success → 結果画像 + 保存・再生成 / failure → 文言 + 復帰導線。
//

import SwiftUI

struct TryOnView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TryOnViewModel

    /// SAFETY 失敗時の「顔写真を変更」導線 (TryOnEntryModifier が顔登録シートへ戻す)
    let onChangeFace: (() -> Void)?

    init(source: TryOnSource,
         client: TryOnClientProtocol = TryOnClient(),
         onChangeFace: (() -> Void)? = nil,
         faceDataOverride: Data? = nil) {
        _viewModel = State(initialValue: TryOnViewModel(
            source: source, client: client, faceDataOverride: faceDataOverride))
        self.onChangeFace = onChangeFace
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.08))
                .navigationTitle("試着")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") {
                            viewModel.cancel()
                            dismiss()
                        }
                    }
                }
        }
        .task { viewModel.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            TryOnLoadingView(
                faceImage: FaceImageStore.shared.thumbnail(),
                thumbnailURLs: viewModel.source.thumbnailURLs,
                onCancel: {
                    viewModel.cancel()
                    dismiss()
                })
        case .success(let image, let fromCache):
            resultView(image: image, fromCache: fromCache)
        case .failure(let failure):
            failureView(failure)
        }
    }

    // MARK: - 結果

    private func resultView(image: UIImage, fromCache: Bool) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 3)
                        if fromCache {
                            Text("前回の試着結果")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                    }
                    Text("AIが生成した試着イメージです。実際の見え方と異なる場合があります。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            VStack(spacing: 8) {
                Button {
                    Haptic.impact(.soft)
                    viewModel.saveToPhotos()
                } label: {
                    Label(viewModel.didSaveToPhotos ? "保存しました" : "写真に保存",
                          systemImage: viewModel.didSaveToPhotos ? "checkmark" : "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.didSaveToPhotos ? Color.black.opacity(0.5) : .black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.didSaveToPhotos)

                Button {
                    Haptic.impact(.soft)
                    viewModel.regenerate()
                } label: {
                    Label("高品質でもう一度生成", systemImage: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    // MARK: - 失敗

    private func failureView(_ failure: TryOnFailure) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: failure.suggestsFaceChange
                  ? "person.crop.circle.badge.exclamationmark"
                  : "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(failure.message)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()

            VStack(spacing: 8) {
                if failure.allowsRetry {
                    Button {
                        Haptic.impact(.soft)
                        viewModel.regenerate()
                    } label: {
                        Text("もう一度試す")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                if failure.suggestsFaceChange, let onChangeFace {
                    Button {
                        Haptic.impact(.soft)
                        dismiss()
                        onChangeFace()
                    } label: {
                        Text("顔写真を変更する")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Preview

private let previewSource = TryOnSource.snap(
    id: "preview-pool",
    imageURL: "https://i.pinimg.com/736x/a6/5a/50/a65a50686f1c10f5c98f2bedd434bf1e.jpg",
    labels: ["トップス: 白シャツ", "ボトムス: ワイドパンツ"])

#Preview("Mock (2秒)") {
    TryOnView(source: previewSource, client: MockTryOnClient(),
              faceDataOverride: Data([0xFF]))
}

#Preview("Mock 遅延 (10秒)") {
    TryOnView(source: previewSource, client: MockTryOnClient(delaySeconds: 10),
              faceDataOverride: Data([0xFF]))
}

#Preview("Mock 失敗 (SAFETY)") {
    TryOnView(
        source: previewSource,
        client: MockTryOnClient(
            delaySeconds: 1,
            fixedResult: .failure(TryOnAPIError(code: "SAFETY", message: ""))),
        onChangeFace: {},
        faceDataOverride: Data([0xFF]))
}

#Preview("実API (要顔登録)") {
    TryOnView(source: previewSource)
}
