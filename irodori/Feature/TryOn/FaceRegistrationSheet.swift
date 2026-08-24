//
//  FaceRegistrationSheet.swift
//  irodori
//
//  試着に使う顔写真の登録シート。
//  フロントカメラ (CameraImagePicker) / ライブラリ → Vision で顔検出バリデーション
//  → 顔クロップのプレビュー確認 → FaceImageStore へ保存 → onRegistered()。
//

import SwiftUI
import PhotosUI

struct FaceRegistrationSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// 保存完了後に呼ばれる (呼び出し側がそのまま試着へ進める)
    let onRegistered: () -> Void

    @State private var pickedImage: UIImage?
    @State private var faceCrop: UIImage?
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            Group {
                if let faceCrop, let pickedImage {
                    confirmView(faceCrop: faceCrop, original: pickedImage)
                } else {
                    introView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.08))
            .navigationTitle("顔写真の登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(sourceType: .camera) { image in
                showCamera = false
                if let image { process(image) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            isProcessing = true
            Task {
                defer { isProcessing = false }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    process(image)
                } else {
                    errorMessage = "写真を読み込めませんでした。別の写真をお試しください。"
                }
                libraryItem = nil
            }
        }
    }

    // MARK: - 説明 + 撮影/選択

    private var introView: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.black.opacity(0.7))

            Text("あなたの顔写真を登録")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 16)

            Text("登録した顔写真をもとに、コーデを着た\nあなたの試着イメージをAIが生成します。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 8)

            // FaceImageStore のプライバシー方針と対 (変更時は両方更新)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text("顔写真はこの端末の中だけに保存されます。試着イメージの生成時のみ送信され、サーバーには保存されません。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.top, 20)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 8) {
                Button {
                    Haptic.impact(.soft)
                    errorMessage = nil
                    showCamera = true
                } label: {
                    Label("カメラで撮る", systemImage: "camera")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label("ライブラリから選ぶ", systemImage: "photo.on.rectangle")
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
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .overlay {
                if isProcessing { ProgressView() }
            }
        }
    }

    // MARK: - プレビュー確認

    private func confirmView(faceCrop: UIImage, original: UIImage) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(uiImage: faceCrop)
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 180)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 4))
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)

            Text("この写真で試着しますか？")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 20)

            Text("顔がはっきり写っているほど、\n試着イメージの仕上がりが良くなります。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 6)

            Spacer()

            VStack(spacing: 8) {
                Button {
                    Haptic.notify(.success)
                    let saved = FaceImageStore.shared.save(original: original, faceCrop: faceCrop)
                    if saved {
                        onRegistered()
                    } else {
                        errorMessage = "保存に失敗しました。もう一度お試しください。"
                        reset()
                    }
                } label: {
                    Text("この写真で試着する")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    Haptic.impact(.soft)
                    reset()
                } label: {
                    Text("選び直す")
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
            .padding(.bottom, 16)
        }
    }

    // MARK: - 顔検出

    /// Vision で最大の顔をクロップし、プレビュー確認へ進める。顔が取れなければエラー表示。
    private func process(_ image: UIImage) {
        let fixed = image.fixedOrientation()
        guard let cgImage = fixed.cgImage,
              let crop = DetectFace().cropLargestFace(in: cgImage) else {
            errorMessage = "顔を検出できませんでした。顔がはっきり写った写真を選んでください。"
            return
        }
        errorMessage = nil
        pickedImage = fixed
        faceCrop = UIImage(cgImage: crop)
    }

    private func reset() {
        pickedImage = nil
        faceCrop = nil
    }
}

#Preview("顔写真の登録") {
    Color.clear.sheet(isPresented: .constant(true)) {
        FaceRegistrationSheet(onRegistered: {})
    }
}
