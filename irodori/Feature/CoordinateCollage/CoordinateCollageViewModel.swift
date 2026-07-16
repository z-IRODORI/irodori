//
//  CoordinateCollageViewModel.swift
//  irodori
//
//  コーデコラージュ生成画面の ViewModel。
//  入力(コーデ3枚以上 + 背景色) → ローディング → 結果(編集) の 3 ステップを管理する。
//
//  生成・編集・合成はすべて端末内で完結する (PersonCollageEngine):
//   - 切り抜き済み画像はそのまま、未切り抜きは Vision で人物を切り抜く
//   - 初期レイアウトはサーバーと同仕様の段組配置 (seed 付きで「別パターン」も即時)
//   - 結果画面はそのまま編集キャンバス (移動/拡縮/回転/前後/かくす/背景色/undo/リセット)
//   - シェア/保存時にキャンバスと同じ見た目で 1080x1440 PNG を合成する
//

import SwiftUI
import Photos

@Observable
@MainActor
final class CoordinateCollageViewModel {
    enum Step { case input, loading, result }

    private let listClient: CoordinateListClientProtocol

    /// 登録済みコーデのサムネ (http URL)
    struct RegisteredCoordinate: Identifiable, Hashable {
        let id: String
        let url: String            // 撮影画像URL (選択グリッド表示用)
        let cutoutURL: String?     // 人物切り取り後URL (あれば Vision 切り抜きを省く)
    }

    // ステップ
    var step: Step = .input

    // 選択ソース
    var registeredCoordinates: [RegisteredCoordinate] = []
    var selectedCoordinateIDs: Set<String> = []
    var pickedImages: [UIImage] = []

    // 設定
    var backgroundColor: Color = Color(red: 1.0, green: 140.0 / 255.0, blue: 66.0 / 255.0)  // #FF8C42 オレンジ

    // 状態
    var isLoadingCoordinates = false
    var isShuffling = false
    var resultImage: UIImage?
    var errorMessage: String?

    // 編集状態 (結果画面 = 編集キャンバス)
    var collageLayers: [PersonCollageLayer] = []
    var stickerImages: [String: UIImage] = [:]
    var selectedLayerId: String?
    /// ステッカーの生成順 (defaultLayout の "person-i" と同じ並び)
    private var orderedStickers: [UIImage] = []
    private var defaultLayers: [PersonCollageLayer] = []
    private var undoStack: [[PersonCollageLayer]] = []
    private let maxUndoCount = 20

    // 拡縮の上下限 (正規化)。小さすぎて掴めない/大きすぎて破綻するのを防ぐ
    private let minSide = 0.06
    private let maxSide = 1.4

    /// 生成に使った合計枚数 (結果画面のキャプション用)
    private(set) var generatedImageCount = 0

    /// 準備済みの入力画像データ。選択が変わるまで再利用する
    private var preparedImageData: [Data] = []
    /// 入力画像に対応する人物切り抜き (Vision は重いので選択が変わるまでキャッシュ)
    private var cutoutCache: [UIImage] = []
    private var generationTask: Task<Void, Never>?

    /// 直近何ヶ月分の登録コーデを取得するか
    private let monthsToFetch = 6

    /// 切り抜き前に縮小する長辺 (px)。1080x1440 キャンバスへの描画には十分な解像度
    private let cutoutLongEdge: CGFloat = 1600

    init(listClient: CoordinateListClientProtocol = CoordinateListClient()) {
        self.listClient = listClient
    }

    // MARK: - Derived

    /// 選択合計枚数 (登録コーデ + 写真フォルダ)
    var totalSelectedCount: Int {
        selectedCoordinateIDs.count + pickedImages.count
    }

    /// 生成に必要な残り枚数
    var remainingCount: Int {
        max(0, 3 - totalSelectedCount)
    }

    /// 生成可能か (3枚以上選択)
    var canGenerate: Bool {
        totalSelectedCount >= 3
    }

    // 編集系の派生状態
    var visibleLayers: [PersonCollageLayer] { collageLayers.filter { !$0.hidden } }
    var hiddenLayers: [PersonCollageLayer] { collageLayers.filter(\.hidden) }
    var canUndo: Bool { !undoStack.isEmpty }
    var canReset: Bool { collageLayers != defaultLayers }
    var selectedLayer: PersonCollageLayer? { collageLayers.first { $0.id == selectedLayerId } }

    /// 選択中レイヤーが最背面か (背面へ ボタンの活性判定)
    var selectedIsBottom: Bool {
        guard let sel = selectedLayer else { return true }
        return sel.z == visibleLayers.map(\.z).min()
    }

    // MARK: - Load registered coordinates

    func loadRegisteredCoordinates() async {
        guard let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue), !uid.isEmpty else {
            return
        }

        isLoadingCoordinates = true
        defer { isLoadingCoordinates = false }

        let calendar = Calendar.current
        let now = Date()
        var seen = Set<String>()
        var coordinates: [RegisteredCoordinate] = []

        for offset in 0..<monthsToFetch {
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)

            guard let result = try? await listClient.get(uid: uid, year: year, month: month),
                  case .success(let list) = result else {
                continue
            }

            for item in list {
                guard let path = item.coodinate_image_path,
                      !path.isEmpty,
                      path.hasPrefix("http") else { continue }
                let id = item.id ?? path
                if seen.contains(id) { continue }
                seen.insert(id)
                let cutout = (item.cutout_image_path?.isEmpty == false) ? item.cutout_image_path : nil
                coordinates.append(RegisteredCoordinate(id: id, url: path, cutoutURL: cutout))
            }
        }

        registeredCoordinates = coordinates
    }

    // MARK: - Selection

    func toggleCoordinate(_ id: String) {
        if selectedCoordinateIDs.contains(id) {
            selectedCoordinateIDs.remove(id)
        } else {
            selectedCoordinateIDs.insert(id)
        }
        invalidatePreparedData()
    }

    func addPickedImages(_ images: [UIImage]) {
        pickedImages.append(contentsOf: images)
        invalidatePreparedData()
    }

    func removePickedImage(at index: Int) {
        guard pickedImages.indices.contains(index) else { return }
        pickedImages.remove(at: index)
        invalidatePreparedData()
    }

    /// 選択が変わったので準備済みデータと切り抜きキャッシュを無効化
    private func invalidatePreparedData() {
        preparedImageData = []
        cutoutCache = []
    }

    // MARK: - Generate (端末内で切り抜き → 配置 → 合成)

    func generate() {
        guard canGenerate, step != .loading else { return }
        errorMessage = nil
        step = .loading
        generationTask = Task { await runGenerate() }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        step = .input
    }

    func backToInput() {
        step = .input
        errorMessage = nil
    }

    private func runGenerate() async {
        do {
            let images = try await prepareImageDataIfNeeded()
            guard images.count >= 3 else {
                failBackToInput("画像の準備に失敗しました。もう一度お試しください")
                return
            }
            try Task.checkCancellation()

            let cutouts = await ensureCutouts(from: images)
            try Task.checkCancellation()
            guard !cutouts.isEmpty else {
                failBackToInput("人物が写っている画像が見つかりませんでした。別のコーデでお試しください")
                return
            }

            // ステッカー化 (白縁) は CPU が重いのでメインアクター外で
            let stickers = await Task.detached(priority: .userInitiated) {
                cutouts.map { PersonCollageEngine.makeSticker(from: $0) }
            }.value
            try Task.checkCancellation()

            orderedStickers = stickers
            stickerImages = Dictionary(
                uniqueKeysWithValues: stickers.enumerated().map { ("person-\($0.offset)", $0.element) }
            )
            generatedImageCount = cutouts.count
            applyNewLayout(seed: UInt64.random(in: UInt64.min...UInt64.max))
            step = .result
            Haptic.notify(.success)
        } catch is CancellationError {
            // キャンセル時は cancelGeneration() が既に .input へ戻している
        } catch {
            failBackToInput("コラージュの生成に失敗しました。もう一度お試しください")
        }
    }

    /// 別パターンで作る: 同じ切り抜きのまま新しい seed で配置し直す (端末内・即時)
    func shuffle() async {
        guard !stickerImages.isEmpty, !isShuffling else { return }
        isShuffling = true
        defer { isShuffling = false }
        applyNewLayout(seed: UInt64.random(in: UInt64.min...UInt64.max))
        Haptic.notify(.success)
    }

    /// 新しい初期レイアウトを適用する (編集履歴はクリア)。
    /// defaultLayout の "person-i" は orderedStickers / stickerImages のキーと同じ振り番
    private func applyNewLayout(seed: UInt64) {
        let layout = PersonCollageEngine.defaultLayout(stickers: orderedStickers, seed: seed)
        collageLayers = layout
        defaultLayers = layout
        undoStack.removeAll()
        selectedLayerId = nil
        recompose()
    }

    private func failBackToInput(_ message: String) {
        guard !Task.isCancelled else { return }
        errorMessage = message
        step = .input
        Haptic.notify(.error)
    }

    private func prepareImageDataIfNeeded() async throws -> [Data] {
        if !preparedImageData.isEmpty { return preparedImageData }

        var imageDataList: [Data] = []

        // 1. 選択した登録コーデをダウンロード。
        //    切り取り済み画像があれば透過保持の PNG を使い、端末での Vision 切り抜きを省く。
        let selectedCoords = registeredCoordinates
            .filter { selectedCoordinateIDs.contains($0.id) }
        for coord in selectedCoords {
            try Task.checkCancellation()
            let useCutout = (coord.cutoutURL?.isEmpty == false)
            let urlString = useCutout ? (coord.cutoutURL ?? coord.url) : coord.url
            guard let url = URL(string: urlString),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else {
                continue
            }
            let prepared = image.fixedOrientation().resizedToFit(longEdge: cutoutLongEdge)
            // 切り取り画像は透過を保つため PNG、撮影画像は JPEG
            let encoded = useCutout ? prepared.pngData() : prepared.jpegData(compressionQuality: 0.8)
            if let encoded {
                imageDataList.append(encoded)
            }
        }

        // 2. 写真フォルダから選んだ画像
        for image in pickedImages {
            if let jpeg = image.fixedOrientation()
                .resizedToFit(longEdge: cutoutLongEdge)
                .jpegData(compressionQuality: 0.8) {
                imageDataList.append(jpeg)
            }
        }

        preparedImageData = imageDataList
        return imageDataList
    }

    /// 入力画像 → 人物切り抜き。選択が変わるまでキャッシュして Vision の再実行を避ける
    private func ensureCutouts(from images: [Data]) async -> [UIImage] {
        if !cutoutCache.isEmpty { return cutoutCache }
        let cutouts = await PersonCollageEngine.prepareCutouts(from: images)
        cutoutCache = cutouts
        return cutouts
    }

    // MARK: - 編集操作 (ジェスチャー中は直接更新し、確定時に commitGesture で undo を積む)

    /// レイヤーを移動。中心がキャンバス内に留まるようクランプする
    func moveLayer(_ id: String, toX x: Double, toY y: Double) {
        guard let index = collageLayers.firstIndex(where: { $0.id == id }) else { return }
        let layer = collageLayers[index]
        collageLayers[index].x = min(max(x, 0.03 - layer.w / 2), 0.97 - layer.w / 2)
        collageLayers[index].y = min(max(y, 0.03 - layer.h / 2), 0.97 - layer.h / 2)
    }

    /// ピンチ/ハンドル開始時の rect を基準に、中心固定・アスペクト維持で拡縮する
    func scaleLayer(_ id: String, from start: PersonCollageLayer, factor: Double) {
        guard let index = collageLayers.firstIndex(where: { $0.id == id }) else { return }
        let maxFactor = min(maxSide / start.w, maxSide / start.h)
        let minFactor = max(minSide / start.w, minSide / start.h)
        guard minFactor <= maxFactor else { return }
        let f = min(max(factor, minFactor), maxFactor)
        let newW = start.w * f
        let newH = start.h * f
        collageLayers[index].x = start.x + (start.w - newW) / 2
        collageLayers[index].y = start.y + (start.h - newH) / 2
        collageLayers[index].w = newW
        collageLayers[index].h = newH
    }

    /// 回転開始時の角度を基準に delta (度) を加える
    func rotateLayer(_ id: String, from start: PersonCollageLayer, delta: Double) {
        guard let index = collageLayers.firstIndex(where: { $0.id == id }) else { return }
        var angle = (start.r + delta).truncatingRemainder(dividingBy: 360)
        if angle > 180 { angle -= 360 }
        if angle < -180 { angle += 360 }
        collageLayers[index].r = angle
    }

    /// ジェスチャー確定。開始時 snapshot と差分があれば undo に積み、合成画像を更新する
    func commitGesture(snapshot: [PersonCollageLayer]) {
        guard collageLayers != snapshot else { return }
        pushUndo(snapshot)
        recompose()
    }

    /// タップしたレイヤーを最前面へ (既に最前面なら何もしない)
    func bringToFront(_ id: String) {
        guard let index = collageLayers.firstIndex(where: { $0.id == id }) else { return }
        let maxZ = collageLayers.map(\.z).max() ?? 0
        guard collageLayers[index].z != maxZ else { return }
        pushUndo(collageLayers)
        collageLayers[index].z = maxZ + 1
        normalizeZ()
        recompose()
    }

    /// z 順で1段だけ背面へ
    func sendBackward(_ id: String) {
        let ordered = collageLayers.sorted { $0.z < $1.z }
        guard let position = ordered.firstIndex(where: { $0.id == id }), position > 0 else { return }
        let neighborId = ordered[position - 1].id
        guard let i = collageLayers.firstIndex(where: { $0.id == id }),
              let j = collageLayers.firstIndex(where: { $0.id == neighborId }) else { return }
        pushUndo(collageLayers)
        let z = collageLayers[i].z
        collageLayers[i].z = collageLayers[j].z
        collageLayers[j].z = z
        recompose()
    }

    /// 選択中レイヤーをかくす (コラージュから除外。あとで戻せる)
    func hideSelectedLayer() {
        guard let id = selectedLayerId,
              let index = collageLayers.firstIndex(where: { $0.id == id }) else { return }
        // 全員かくすと空のコラージュになるので最後の1人は残す
        guard visibleLayers.count > 1 else {
            ToastManager.shared.show("最後の1人はかくせません")
            return
        }
        pushUndo(collageLayers)
        collageLayers[index].hidden = true
        selectedLayerId = nil
        recompose()
    }

    /// かくしたレイヤーを戻す (最前面に出す)
    func restoreLayer(_ id: String) {
        guard let index = collageLayers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo(collageLayers)
        collageLayers[index].hidden = false
        collageLayers[index].z = (collageLayers.map(\.z).max() ?? 0) + 1
        normalizeZ()
        selectedLayerId = id
        recompose()
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        collageLayers = last
        recompose()
    }

    func resetToDefault() {
        guard canReset else { return }
        pushUndo(collageLayers)
        collageLayers = defaultLayers
        selectedLayerId = nil
        recompose()
    }

    /// 背景色の変更 (結果画面のスウォッチから)。ロゴの白黒も切り替わる
    func updateBackgroundColor(_ color: Color) {
        backgroundColor = color
        recompose()
    }

    /// z を表示順ランク (0..n-1) に振り直す
    private func normalizeZ() {
        let orderedIds = collageLayers.sorted { $0.z < $1.z }.map(\.id)
        for (rank, layerId) in orderedIds.enumerated() {
            if let i = collageLayers.firstIndex(where: { $0.id == layerId }) {
                collageLayers[i].z = rank
            }
        }
    }

    private func pushUndo(_ snapshot: [PersonCollageLayer]) {
        undoStack.append(snapshot)
        if undoStack.count > maxUndoCount {
            undoStack.removeFirst()
        }
    }

    /// 現在の配置でシェア/保存用の 1080x1440 PNG を合成し直す
    private func recompose() {
        resultImage = PersonCollageEngine.compose(
            layers: collageLayers,
            stickers: stickerImages,
            background: UIColor(backgroundColor)
        )
    }

    // MARK: - Save to Photos

    func saveResultToPhotos() {
        guard let image = resultImage else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    Haptic.notify(.error)
                    ToastManager.shared.show("写真へのアクセスが許可されていません。設定から許可してください")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                Task { @MainActor in
                    if success {
                        Haptic.notify(.success)
                        ToastManager.shared.show("写真に保存しました", style: .normal)
                    } else {
                        Haptic.notify(.error)
                        ToastManager.shared.show("保存に失敗しました。もう一度お試しください")
                    }
                }
            }
        }
    }
}

// MARK: - Color → Hex

extension Color {
    /// SwiftUI Color を "#RRGGBB" 文字列に変換する
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let r = Int(round(max(0, min(1, red)) * 255))
        let g = Int(round(max(0, min(1, green)) * 255))
        let b = Int(round(max(0, min(1, blue)) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
