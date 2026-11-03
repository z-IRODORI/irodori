//
//  FullBodyPickerView.swift
//  irodori
//
//  本人が写った写真1枚をもとに、フォトライブラリから「本人の全身写真」をピックアップする機能。
//  3ステップ:
//    ① 準備: 本人が写った写真を1枚選ぶ + 対象期間 (枚数と所要時間は実測から見積もる)
//    ② 検索中: 画面を閉じても裏で続ける (FullBodyScanStore。画面の下のトーストで進み具合と見つかった枚数を出す)
//    ③ 候補: これまでに見つけた写真から選んで追加 (候補は端末に保存し、いつでも開ける)
//

import SwiftUI
import PhotosUI

// MARK: - ブランドのグラデーション

private let brandGradient = LinearGradient(
    colors: [Color(red: 1.0, green: 0.27, blue: 0.42), Color(red: 1.0, green: 0.45, blue: 0.30)],
    startPoint: .leading, endPoint: .trailing
)

// MARK: - 走査オプション

enum ScanPeriod: Int, CaseIterable, Identifiable {
    case month1 = 1, month3 = 3, month6 = 6, year1 = 12, year2 = 24
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .month1: return "1ヶ月"
        case .month3: return "3ヶ月"
        case .month6: return "6ヶ月"
        case .year1: return "1年"
        case .year2: return "2年"
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class FullBodyPickerViewModel {
    enum Step { case setup, searching, result }

    var step: Step = .setup
    var faceImage: UIImage?
    var selected: Set<String> = []
    var errorMessage: String?
    var scanPeriod: ScanPeriod = .year1 {
        didSet { if oldValue != scanPeriod { refreshEstimate() } }
    }

    /// 対象期間の写真の枚数 (nil = 未取得 / 写真へのアクセス不可)
    var photoCount: Int?
    /// 1枚あたりの解析秒数 (端末で実測。前回の実行結果があればそれを優先)
    var secondsPerPhoto: Double?
    var isMeasuring = false
    var photoAccessDenied = false

    private let service = FullBodyPickerService()
    private static let measuredRateKey = "fullBodyPicker.secondsPerPhoto"

    /// 見積もりの所要時間 (秒)
    var estimatedSeconds: Double? {
        guard let photoCount, let secondsPerPhoto else { return nil }
        return Double(photoCount) * secondsPerPhoto
    }

    /// 「数秒」「約40秒」「約1分30秒」の形に整える (8秒未満は「数秒」、1分未満は5秒刻み、それ以上は10秒刻み)
    static func durationLabel(_ seconds: Double) -> String {
        if seconds < 8 { return "数秒" }
        let s = seconds
        if s < 60 { return "約\(Int((s / 5).rounded()) * 5)秒" }
        let rounded = Int((s / 10).rounded()) * 10
        let m = rounded / 60, r = rounded % 60
        return r == 0 ? "約\(m)分" : "約\(m)分\(r)秒"
    }

    /// 画面表示時: 写真へのアクセスを確認し、枚数と1枚あたりの秒数を測る
    func prepare() async {
        guard await service.requestAuthorization() else {
            photoAccessDenied = true
            return
        }
        if let saved = UserDefaults.standard.object(forKey: Self.measuredRateKey) as? Double, saved > 0 {
            secondsPerPhoto = saved
        }
        refreshEstimate()
    }

    private func refreshEstimate() {
        guard !photoAccessDenied else { return }
        let months = scanPeriod.rawValue
        photoCount = service.photoCount(months: months)
        // 前回の実行で測った値が無いときだけ、数枚を実際に解析して測る
        guard UserDefaults.standard.object(forKey: Self.measuredRateKey) == nil, !isMeasuring else { return }
        isMeasuring = true
        let service = self.service
        Task {
            let rate = await Task.detached(priority: .utility) {
                await service.measureSecondsPerPhoto(months: months)
            }.value
            if let rate { self.secondsPerPhoto = rate }
            self.isMeasuring = false
        }
    }

    /// 選択した画像を顔中心の正方形に切り抜いてセット
    func setFaceImage(_ image: UIImage) {
        faceImage = Self.squareFaceCrop(image)
        errorMessage = nil
    }

    /// 裏で検索を始める。始められたら true (画面を閉じてほかの操作に戻ってよい)
    func startSearchInBackground() async -> Bool {
        guard let faceImage else { return false }
        let ok = await FullBodyScanStore.shared.start(
            faceImage: faceImage, months: scanPeriod.rawValue, photoCount: photoCount ?? 0)
        if !ok {
            errorMessage = "顔を認識できませんでした。顔がはっきり写った写真を選んでください。"
        }
        return ok
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    /// 選んだ写真を、送るための大きさで読み直す
    func loadSelectedImages() async -> [UIImage] {
        var images: [UIImage] = []
        for c in FullBodyScanStore.shared.saved where selected.contains(c.id) {
            if let image = await FullBodyPickerService.loadImage(localIdentifier: c.id, target: CGSize(width: 1600, height: 1600)) {
                images.append(image)
            }
        }
        return images
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
    private var store = FullBodyScanStore.shared

    init(onComplete: @escaping ([UIImage]) -> Void, onClose: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onClose = onClose
        // 検索中ならその様子、見つけた写真があれば候補、無ければ準備から
        let vm = FullBodyPickerViewModel()
        if FullBodyScanStore.shared.isScanning {
            vm.step = .searching
        } else if !FullBodyScanStore.shared.saved.isEmpty {
            vm.step = .result
        }
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.step {
            case .setup:
                SetupStep(viewModel: viewModel, onClose: onClose)
            case .searching:
                SearchingStep(viewModel: viewModel, onClose: onClose)
            case .result:
                ResultStep(viewModel: viewModel, onClose: onClose, onComplete: onComplete)
            }
        }
        .background(Color.white)
        .onChange(of: store.phase) { _, phase in
            if phase == .finished, viewModel.step == .searching {
                store.hideToast()
                viewModel.step = .result
            }
        }
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
                    CloseCircleButton(action: onClose)
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

// MARK: - ① 準備 (写真1枚 + 対象期間)

private struct SetupStep: View {
    @Bindable var viewModel: FullBodyPickerViewModel
    let onClose: () -> Void

    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "AIで全身写真を選ぶ", onClose: onClose, showProgress: true, activeSegments: 1)

            ScrollView {
                VStack(spacing: 18) {
                    Text("あなたが写った写真を1枚選ぶと、写真ライブラリから\nあなたが全身で写った写真を探します。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    // 写真プレビュー（正方形・顔中心に切り抜き）
                    facePreview

                    if let msg = viewModel.errorMessage {
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if viewModel.faceImage != nil {
                        PhotosPicker(selection: $libraryItem, matching: .images) {
                            Text("別の写真にする")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.pink)
                                .underline()
                        }
                    }

                    scanSettings
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            Button {
                Haptic.impact(.medium)
                Task {
                    // 裏で探すので、画面は閉じてほかの操作に戻る (進み具合は画面の下のトーストで見える)
                    if await viewModel.startSearchInBackground() { onClose() }
                }
            } label: {
                Text("全身写真を探す")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.faceImage == nil ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(brandGradient))
                    .clipShape(Capsule())
            }
            .disabled(viewModel.faceImage == nil || viewModel.photoCount == 0)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .task { await viewModel.prepare() }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.setFaceImage(image)
                }
            }
        }
    }

    /// 対象期間を選ぶだけ。枚数と所要時間はその場で見積もって伝える
    private var scanSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("対象期間")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
            Picker("対象期間", selection: $viewModel.scanPeriod) {
                ForEach(ScanPeriod.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            estimateRow
        }
        .padding(14)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var estimateRow: some View {
        if viewModel.photoAccessDenied {
            Text("写真へのアクセスが許可されていません。設定アプリから許可してください。")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        } else if let count = viewModel.photoCount {
            HStack(spacing: 16) {
                estimateItem(icon: "photo.on.rectangle", title: "写真", value: "\(count.formatted())枚")
                estimateItem(icon: "clock", title: "所要時間", value: timeText(count: count))
                Spacer(minLength: 0)
            }
            if count == 0 {
                Text("この期間の写真はありません。期間を広げてください。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("写真の枚数を数えています")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timeText(count: Int) -> String {
        if count == 0 { return "—" }
        if let s = viewModel.estimatedSeconds { return FullBodyPickerViewModel.durationLabel(s) }
        return viewModel.isMeasuring ? "計測中…" : "—"
    }

    private func estimateItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.pink)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(.black)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
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
                    Text("あなたが写った写真を選ぶ")
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

// MARK: - ② 検索中 (裏で続く。ここでは様子だけ見せる)

private struct SearchingStep: View {
    let viewModel: FullBodyPickerViewModel
    let onClose: () -> Void

    private var store: FullBodyScanStore { FullBodyScanStore.shared }
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "写真を検索中", onClose: onClose, showProgress: true, activeSegments: 2)

            Spacer()

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
            .padding(.vertical, 32)
            .onAppear { pulse = true }

            // 見つかった枚数をその場で増やす
            Text("\(store.foundCount)枚見つかりました")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: store.foundCount)
            Text("\(Int(store.progress * 100))%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.top, 4)

            ProgressView(value: store.progress)
                .tint(.pink)
                .padding(.horizontal, 60)
                .padding(.top, 8)

            Text("閉じても探し続けます。\n進み具合は画面の下に出ます。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            Spacer()

            Button {
                Haptic.impact(.soft)
                onClose()
            } label: {
                Text("閉じてほかのことをする")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(Capsule().stroke(Color.black.opacity(0.15), lineWidth: 1))
            }
            .padding(.horizontal, 24)

            Text("写真はこの端末の中だけで解析され、\n外部に送信・保存されることはありません。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
        }
    }
}

// MARK: - ③ 候補 (これまでに見つけた写真。いつでも開いて選べる)

private struct ResultStep: View {
    @Bindable var viewModel: FullBodyPickerViewModel
    let onClose: () -> Void
    let onComplete: ([UIImage]) -> Void

    private var store: FullBodyScanStore { FullBodyScanStore.shared }
    @State private var isSending = false
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "見つけた全身写真", onClose: onClose, showProgress: true, activeSegments: 3)

            if store.saved.isEmpty {
                emptyState
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("追加したい写真を選んでください（\(store.saved.count)枚）")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button("もう一度探す") { viewModel.step = .setup }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.pink)
                        .disabled(store.isScanning)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(store.saved) { candidate in
                            CandidateCell(candidate: candidate,
                                          isSelected: viewModel.selected.contains(candidate.id)) {
                                Haptic.impact(.soft)
                                viewModel.toggle(candidate.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                addButton
            }
        }
    }

    private var addButton: some View {
        Button {
            Haptic.impact(.medium)
            isSending = true
            Task {
                let images = await viewModel.loadSelectedImages()
                isSending = false
                onComplete(images)
            }
        } label: {
            Group {
                if isSending {
                    ProgressView().tint(.white)
                } else {
                    Text(viewModel.selected.isEmpty ? "写真を選んでください" : "\(viewModel.selected.count)枚の写真を追加")
                }
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.selected.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(brandGradient))
            .clipShape(Capsule())
        }
        .disabled(viewModel.selected.isEmpty || isSending)
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
            Text("別の写真や、より長い対象期間でもう一度お試しください。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("条件を変えて探す") { viewModel.step = .setup }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.pink)
                .padding(.top, 4)
            Spacer()
        }
    }
}

/// 候補の1枚 (写真フォルダから読み直して出す。写真が消されていたら灰色のまま)
private struct CandidateCell: View {
    let candidate: FullBodyScanStore.SavedCandidate
    let isSelected: Bool
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geo in
                ZStack {
                    Color.gray.opacity(0.1)
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                }
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
        .task(id: candidate.id) {
            image = await FullBodyPickerService.loadImage(localIdentifier: candidate.id, target: CGSize(width: 400, height: 400))
        }
    }
}

// MARK: - カメラ（FaceRegistrationSheet で使用）

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
