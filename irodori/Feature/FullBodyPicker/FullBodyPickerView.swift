//
//  FullBodyPickerView.swift
//  irodori
//
//  顔写真から、フォトライブラリの「対象ユーザーの全身写真」をピックアップする機能。
//  Tinder の「AIフォトセレクト」風の4ステップフロー:
//    ① エントリ（AIで選ぶ / ライブラリから選ぶ）
//    ② 顔写真を使う（撮影 or 選択 → 正方形に自動切り抜き）
//    ③ 検索中（ローディング・進捗）
//    ④ 結果の確認（候補グリッドから選んで追加）
//

import SwiftUI
import PhotosUI

// MARK: - ブランドのグラデーション

private let brandGradient = LinearGradient(
    colors: [Color(red: 1.0, green: 0.27, blue: 0.42), Color(red: 1.0, green: 0.45, blue: 0.30)],
    startPoint: .leading, endPoint: .trailing
)

// MARK: - ViewModel

@MainActor
@Observable
final class FullBodyPickerViewModel {
    enum Step { case entry, faceInput, searching, result }

    var step: Step = .entry
    var faceImage: UIImage?
    var progress: Double = 0
    var candidates: [FullBodyCandidate] = []
    var selected: Set<String> = []
    var errorMessage: String?

    private let service = FullBodyPickerService()

    /// 選択/撮影した画像を顔中心の正方形に切り抜いてセット
    func setFaceImage(_ image: UIImage) {
        faceImage = Self.squareFaceCrop(image)
        errorMessage = nil
    }

    func startSearch() {
        guard let faceImage else { return }
        step = .searching
        progress = 0
        candidates = []
        selected = []

        let service = self.service
        Task {
            // embedding 抽出（重いのでバックグラウンド）
            let emb = await Task.detached(priority: .userInitiated) {
                service.targetEmbedding(from: faceImage)
            }.value

            guard let emb else {
                self.errorMessage = "顔を認識できませんでした。顔がはっきり写った写真を選んでください。"
                self.step = .faceInput
                return
            }

            let result = await service.pickFullBodyPhotos(targetEmbedding: emb) { p in
                Task { @MainActor in self.progress = p }
            }
            self.candidates = result
            self.step = .result
        }
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    var selectedImages: [UIImage] {
        candidates.filter { selected.contains($0.id) }.map(\.image)
    }

    /// 顔があれば顔中心、無ければ中央を正方形に切り抜く
    private static func squareFaceCrop(_ image: UIImage) -> UIImage {
        if let cg = image.cgImage, let face = DetectFace().cropLargestFace(in: cg) {
            return UIImage(cgImage: face, scale: image.scale, orientation: image.imageOrientation)
        }
        return centerSquare(image)
    }

    private static func centerSquare(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let side = min(w, h)
        let rect = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
        guard let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - フロー全体

struct FullBodyPickerView: View {
    /// 選んだ全身写真を呼び出し元（IRODORIの全身入力）へ渡す
    let onComplete: ([UIImage]) -> Void
    let onClose: () -> Void

    @State private var viewModel = FullBodyPickerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.step {
            case .entry:
                EntryStep(viewModel: viewModel, onClose: onClose, onComplete: onComplete)
            case .faceInput:
                FaceInputStep(viewModel: viewModel, onClose: onClose)
            case .searching:
                SearchingStep(viewModel: viewModel, onClose: onClose)
            case .result:
                ResultStep(viewModel: viewModel, onClose: onClose, onComplete: onComplete)
            }
        }
        .background(Color.white)
    }
}

// MARK: - 共通ヘッダ

private struct PickerHeader: View {
    let title: String
    let onClose: () -> Void
    var showProgress: Bool = false
    var activeSegments: Int = 0  // 0..3

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                    Spacer()
                }
            }
            if showProgress {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i < activeSegments ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.gray.opacity(0.15)))
                            .frame(height: 4)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - ① エントリ

private struct EntryStep: View {
    let viewModel: FullBodyPickerViewModel
    let onClose: () -> Void
    let onComplete: ([UIImage]) -> Void

    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "全身写真を追加", onClose: onClose)

            VStack(spacing: 12) {
                Button {
                    Haptic.impact(.soft)
                    viewModel.step = .faceInput
                } label: {
                    EntryRow(
                        icon: "person.crop.square.badge.camera",
                        title: "AIで全身写真を選ぶ",
                        subtitle: "顔写真から、自分が全身で写った写真を自動で探します。",
                        highlighted: true
                    )
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $libraryItem, matching: .images) {
                    EntryRow(
                        icon: "photo.on.rectangle",
                        title: "写真ライブラリから選ぶ",
                        subtitle: "自分で写真を選んで追加します。",
                        highlighted: false
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Spacer()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onComplete([image])
                }
            }
        }
    }
}

private struct EntryRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(highlighted ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.gray.opacity(0.85)))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray.opacity(0.5))
        }
        .padding(16)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - ② 顔写真を使う

private struct FaceInputStep: View {
    let viewModel: FullBodyPickerViewModel
    let onClose: () -> Void

    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "AIで全身写真を選ぶ", onClose: onClose)

            ScrollView {
                VStack(spacing: 18) {
                    Text("顔写真を使う")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.top, 8)

                    Text("顔写真をもとに、写真ライブラリから\nあなたが全身で写った写真を探します。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // 顔プレビュー（正方形）
                    facePreview

                    if let msg = viewModel.errorMessage {
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        Text("写真ライブラリから選ぶ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.pink)
                            .underline()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            // 下部アクション
            VStack(spacing: 14) {
                Button {
                    Haptic.impact(.medium)
                    viewModel.startSearch()
                } label: {
                    Text("全身写真を探す")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.faceImage == nil ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(brandGradient))
                        .clipShape(Capsule())
                }
                .disabled(viewModel.faceImage == nil)

                Button {
                    Haptic.impact(.soft)
                    showCamera = true
                } label: {
                    Text("自撮り写真を撮る")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.setFaceImage(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(sourceType: .camera) { image in
                if let image { viewModel.setFaceImage(image) }
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var facePreview: some View {
        if let face = viewModel.faceImage {
            Image(uiImage: face)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(brandGradient, lineWidth: 3))
        } else {
            PhotosPicker(selection: $libraryItem, matching: .images) {
                VStack(spacing: 10) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 44))
                        .foregroundStyle(.gray.opacity(0.5))
                    Text("顔写真を選ぶ")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.gray)
                }
                .frame(width: 200, height: 200)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [6])))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - ③ 検索中

private struct SearchingStep: View {
    let viewModel: FullBodyPickerViewModel
    let onClose: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "写真を検索中", onClose: onClose, showProgress: true, activeSegments: 2)

            Spacer()

            Text("最近の写真を調べています。\nそのままお待ちください。")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // 円形ローディング（同心円のパルス）
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.pink.opacity(0.15 - Double(i) * 0.04))
                        .frame(width: 80 + CGFloat(i) * 50, height: 80 + CGFloat(i) * 50)
                        .scaleEffect(pulse ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.2), value: pulse)
                }
                Circle()
                    .fill(brandGradient)
                    .frame(width: 64, height: 64)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 40)
            .onAppear { pulse = true }

            Text("\(Int(viewModel.progress * 100))%")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .monospacedDigit()

            ProgressView(value: viewModel.progress)
                .tint(.pink)
                .padding(.horizontal, 60)
                .padding(.top, 8)

            Spacer()

            Text("写真はこの端末の中だけで解析され、\n外部に送信・保存されることはありません。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - ④ 結果の確認

private struct ResultStep: View {
    let viewModel: FullBodyPickerViewModel
    let onClose: () -> Void
    let onComplete: ([UIImage]) -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "写真の確認", onClose: onClose, showProgress: true, activeSegments: 3)

            if viewModel.candidates.isEmpty {
                emptyState
            } else {
                Text("あなたが全身で写った写真の候補です。追加したい写真を選んでください。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(viewModel.candidates) { candidate in
                            candidateCell(candidate)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                addButton
            }
        }
    }

    private func candidateCell(_ candidate: FullBodyCandidate) -> some View {
        let isSelected = viewModel.selected.contains(candidate.id)
        return Button {
            Haptic.impact(.soft)
            viewModel.toggle(candidate.id)
        } label: {
            GeometryReader { geo in
                Image(uiImage: candidate.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width * 1.3)
                    .clipped()
            }
            .aspectRatio(1.0 / 1.3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AnyShapeStyle(brandGradient) : AnyShapeStyle(.white))
                    .background(Circle().fill(.black.opacity(isSelected ? 0 : 0.15)).frame(width: 24, height: 24))
                    .padding(6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.clear), lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button {
            Haptic.impact(.medium)
            onComplete(viewModel.selectedImages)
        } label: {
            Text(viewModel.selected.isEmpty ? "写真を選んでください" : "\(viewModel.selected.count)枚の写真を追加")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.selected.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(brandGradient))
                .clipShape(Capsule())
        }
        .disabled(viewModel.selected.isEmpty)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.crop.square.badge.questionmark")
                .font(.system(size: 50))
                .foregroundStyle(.gray.opacity(0.5))
            Text("全身が写った写真が見つかりませんでした")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
            Text("別の顔写真でもう一度試すか、ライブラリから直接選んでください。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("顔写真を選び直す") { viewModel.step = .faceInput }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.pink)
                .padding(.top, 4)
            Spacer()
        }
    }
}

// MARK: - カメラ（自撮り）

struct CameraImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onPicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        if picker.sourceType == .camera { picker.cameraDevice = .front }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage?) -> Void
        init(onPicked: @escaping (UIImage?) -> Void) { self.onPicked = onPicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPicked(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPicked(nil)
        }
    }
}
