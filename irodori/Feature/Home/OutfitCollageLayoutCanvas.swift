//
//  OutfitCollageLayoutCanvas.swift
//  irodori
//
//  クローゼットでコーデのインライン配置編集キャンバス。
//  詳細画面のコラージュ表示そのものが編集キャンバスになる:
//   - タップ = 選択 + 最前面へ
//   - ドラッグ = 移動 (中心がキャンバス内に収まるようクランプ)
//   - 右下の◯ハンドル or ピンチ = 拡大縮小 (アスペクト維持・上下限あり)
//   - 2本指回転 = 回転 / 「かくす」でアイテムを合成から除外 (復元可) / 背景色変更
//  レイヤー (透過PNG) とデフォルト配置はサーバー (GET /api/outfit-collage/layout) が用意し、
//  保存 (POST) するとサーバーが同じ配置で PNG を再合成して collage_url が差し替わる。
//
//  座標系: レイヤーの rect はキャンバス比の正規化値 (左上原点 0-1)。
//  ビュー座標との変換は キャンバス実サイズ を掛ける/割るだけで済む。
//

import SwiftUI
import Kingfisher

// MARK: - ViewModel

@MainActor
@Observable
final class OutfitCollageLayoutEditViewModel {
    var isLoading = true
    var loadFailed = false
    var layers: [OutfitCollageLayoutItem] = []
    var selectedId: String? = nil
    var isSaving = false
    var backgroundColor: Color = .white

    private(set) var collageId = ""
    private var defaultLayers: [OutfitCollageLayoutItem] = []
    private var baseline: [OutfitCollageLayoutItem] = []
    private var baselineBackgroundHex = "#FFFFFF"
    private var undoStack: [[OutfitCollageLayoutItem]] = []
    private let maxUndoCount = 20

    // 拡縮の上下限 (正規化)。小さすぎて掴めない/大きすぎて破綻するのを防ぐ
    private let minSide = 0.06
    private let maxSide = 1.4

    private let client: OutfitCollageClientProtocol
    init(client: OutfitCollageClientProtocol = OutfitCollageClient()) {
        self.client = client
    }

    var hasChanges: Bool {
        layers != baseline || backgroundColor.toHexString() != baselineBackgroundHex
    }
    var canUndo: Bool { !undoStack.isEmpty }
    var canReset: Bool { layers != defaultLayers }
    var canvasReady: Bool { !isLoading && !loadFailed && !layers.isEmpty }
    var visibleLayers: [OutfitCollageLayoutItem] { layers.filter { !$0.hidden } }
    var hiddenLayers: [OutfitCollageLayoutItem] { layers.filter(\.hidden) }
    var selectedLayer: OutfitCollageLayoutItem? { layers.first { $0.id == selectedId } }

    /// 選択中レイヤーが最背面か (背面へ ボタンの活性判定)
    var selectedIsBottom: Bool {
        guard let sel = selectedLayer else { return true }
        return sel.z == visibleLayers.map(\.z).min()
    }

    /// 表示中コラージュに対応するレイヤーが未ロードのときだけ取得する。
    /// シャッフル/差し替えで collage_id が変わったら再ロード、保存直後 (id 同期済み) はスキップ。
    func loadIfNeeded(for collageId: String?) async {
        guard let collageId, !collageId.isEmpty else { return }
        if collageId == self.collageId, !layers.isEmpty { return }
        await load()
    }

    func load() async {
        isLoading = true
        loadFailed = false
        selectedId = nil
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        do {
            switch try await client.getLayout(uid: uid, gender: gender) {
            case .success(let response) where response.status == "success" && !response.items.isEmpty:
                layers = response.items
                defaultLayers = response.default_items
                baseline = response.items
                collageId = response.collage_id
                backgroundColor = Color(hexString: response.background_color) ?? .white
                baselineBackgroundHex = backgroundColor.toHexString()
                undoStack.removeAll()
            default:
                loadFailed = true
            }
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
        isLoading = false
    }

    // MARK: 編集操作 (ジェスチャー中は直接更新し、確定時に commitGesture で undo を積む)

    /// レイヤーを移動。中心がキャンバス内に留まるようクランプする
    func move(_ id: String, toX x: Double, toY y: Double) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        let layer = layers[index]
        let clampedX = min(max(x, 0.03 - layer.w / 2), 0.97 - layer.w / 2)
        let clampedY = min(max(y, 0.03 - layer.h / 2), 0.97 - layer.h / 2)
        layers[index].x = clampedX
        layers[index].y = clampedY
    }

    /// ピンチ開始時の rect を基準に、中心固定・アスペクト維持で拡縮する
    func scale(_ id: String, from start: OutfitCollageLayoutItem, factor: Double) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        let f = clampedScaleFactor(factor, start: start)
        let newW = start.w * f
        let newH = start.h * f
        layers[index].x = start.x + (start.w - newW) / 2
        layers[index].y = start.y + (start.h - newH) / 2
        layers[index].w = newW
        layers[index].h = newH
    }

    private func clampedScaleFactor(_ factor: Double, start: OutfitCollageLayoutItem) -> Double {
        let maxFactor = min(maxSide / start.w, maxSide / start.h)
        let minFactor = max(minSide / start.w, minSide / start.h)
        guard minFactor <= maxFactor else { return 1 }
        return min(max(factor, minFactor), maxFactor)
    }

    /// 回転開始時の角度を基準に delta (度) を加える (-180〜180 に正規化)
    func rotate(_ id: String, from start: OutfitCollageLayoutItem, delta: Double) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        var angle = (start.r + delta).truncatingRemainder(dividingBy: 360)
        if angle > 180 { angle -= 360 }
        if angle < -180 { angle += 360 }
        layers[index].r = angle
    }

    /// 選択中レイヤーをかくす (合成から除外。あとで戻せる)
    func hideSelected() {
        guard let id = selectedId,
              let index = layers.firstIndex(where: { $0.id == id }) else { return }
        guard visibleLayers.count > 1 else {
            ToastManager.shared.show("最後の1点はかくせません")
            return
        }
        pushUndo(layers)
        layers[index].hidden = true
        selectedId = nil
    }

    /// かくしたレイヤーを戻す (最前面に出す)
    func restore(_ id: String) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo(layers)
        layers[index].hidden = false
        layers[index].z = (layers.map(\.z).max() ?? 0) + 1
        normalizeZ()
        selectedId = id
    }

    /// ジェスチャー確定。開始時 snapshot と差分があれば undo に積む
    func commitGesture(snapshot: [OutfitCollageLayoutItem]) {
        guard layers != snapshot else { return }
        pushUndo(snapshot)
    }

    /// タップしたアイテムを最前面へ (既に最前面なら何もしない)
    func bringToFront(_ id: String) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        let maxZ = layers.map(\.z).max() ?? 0
        guard layers[index].z != maxZ else { return }
        pushUndo(layers)
        layers[index].z = maxZ + 1
        normalizeZ()
    }

    func sendBackward(_ id: String) {
        swapZWithNeighbor(id, offset: -1)
    }

    /// z を表示順ランク (0..n-1) に振り直す (bringToFront で値が伸び続けないように)
    private func normalizeZ() {
        let orderedIds = layers.sorted { $0.z < $1.z }.map(\.id)
        for (rank, layerId) in orderedIds.enumerated() {
            if let i = layers.firstIndex(where: { $0.id == layerId }) {
                layers[i].z = rank
            }
        }
    }

    /// z 順で隣のレイヤーと z を入れ替える (1段ずつ背面へ)
    private func swapZWithNeighbor(_ id: String, offset: Int) {
        let ordered = layers.sorted { $0.z < $1.z }
        guard let position = ordered.firstIndex(where: { $0.id == id }) else { return }
        let neighborPosition = position + offset
        guard ordered.indices.contains(neighborPosition) else { return }
        let neighborId = ordered[neighborPosition].id
        guard let i = layers.firstIndex(where: { $0.id == id }),
              let j = layers.firstIndex(where: { $0.id == neighborId }) else { return }
        pushUndo(layers)
        let z = layers[i].z
        layers[i].z = layers[j].z
        layers[j].z = z
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        layers = last
    }

    func resetToDefault() {
        guard canReset else { return }
        pushUndo(layers)
        layers = defaultLayers
        backgroundColor = .white
    }

    private func pushUndo(_ snapshot: [OutfitCollageLayoutItem]) {
        undoStack.append(snapshot)
        if undoStack.count > maxUndoCount {
            undoStack.removeFirst()
        }
    }

    // MARK: 保存

    /// 現在の配置をサーバーで再合成して保存する。成功時は新しいレスポンスを返し、
    /// baseline / collageId を同期する (呼び出し側での再ロード不要)。
    func save() async -> OutfitCollageResponse? {
        guard hasChanges, !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        do {
            switch try await client.saveLayout(
                uid: uid, gender: gender, collageId: collageId,
                backgroundColor: backgroundColor.toHexString(), items: layers
            ) {
            case .success(let response):
                baseline = layers
                baselineBackgroundHex = backgroundColor.toHexString()
                undoStack.removeAll()
                collageId = response.collage_id
                selectedId = nil
                return response
            case .failure(let error):
                ToastManager.shared.show(error.errorDescription ?? "配置の保存に失敗しました")
                return nil
            }
        } catch {
            ToastManager.shared.show("配置の保存に失敗しました")
            return nil
        }
    }
}

// MARK: - キャンバス

struct OutfitCollageLayoutCanvas: View {
    let viewModel: OutfitCollageLayoutEditViewModel

    // ジェスチャー中の一時状態 (開始時のレイヤー状態と undo 用スナップショット)
    @State private var dragContext: (id: String, start: OutfitCollageLayoutItem, snapshot: [OutfitCollageLayoutItem])?
    @State private var pinchContext: (id: String, start: OutfitCollageLayoutItem, snapshot: [OutfitCollageLayoutItem])?
    @State private var rotateContext: (id: String, start: OutfitCollageLayoutItem, snapshot: [OutfitCollageLayoutItem])?
    @State private var handleContext: (id: String, start: OutfitCollageLayoutItem, snapshot: [OutfitCollageLayoutItem])?

    // ドラッグの translation を測る固定座標空間。
    // レイヤーは .position で動くため、デフォルトの .local (レイヤー自身の空間) で測ると
    // 「動かす → 空間ごと動く → translation が戻る」のフィードバックループで振動する。
    private static let canvasSpaceName = "outfitCollageLayoutCanvas"

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 何もない場所のタップで選択解除
                viewModel.backgroundColor
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedId = nil }

                ForEach(viewModel.visibleLayers) { layer in
                    layerView(layer, canvasSize: geo.size)
                }
            }
            .clipped()
            .coordinateSpace(name: Self.canvasSpaceName)
            .simultaneousGesture(pinchGesture(canvasSize: geo.size))
            .simultaneousGesture(rotationGesture())
        }
    }

    private func layerView(_ layer: OutfitCollageLayoutItem, canvasSize: CGSize) -> some View {
        let width = layer.w * canvasSize.width
        let height = layer.h * canvasSize.height
        let isSelected = viewModel.selectedId == layer.id

        return KFImage(URL(string: layer.layer_url))
            .placeholder { Color.gray.opacity(0.08) }
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.black.opacity(0.55), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // タップ = 選択 + 最前面へ
                Haptic.impact(.soft)
                viewModel.selectedId = layer.id
                viewModel.bringToFront(layer.id)
            }
            .gesture(dragGesture(for: layer.id, canvasSize: canvasSize))
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    resizeHandle(for: layer.id, canvasSize: canvasSize)
                        .offset(x: 13, y: 13)
                }
            }
            .rotationEffect(.degrees(layer.r))
            .position(
                x: (layer.x + layer.w / 2) * canvasSize.width,
                y: (layer.y + layer.h / 2) * canvasSize.height
            )
            .zIndex(Double(layer.z))
    }

    // 右下のリサイズハンドル (ドラッグで左上固定・アスペクト維持の拡縮)
    private func resizeHandle(for id: String, canvasSize: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
            Circle()
                .stroke(Color.black.opacity(0.45), lineWidth: 1.5)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.black)
        }
        .frame(width: 26, height: 26)
        .contentShape(Circle().inset(by: -10))   // 指で掴みやすいようヒット領域を拡大
        .gesture(handleDragGesture(for: id, canvasSize: canvasSize))
    }

    private func handleDragGesture(for id: String, canvasSize: CGSize) -> some Gesture {
        // ハンドルは拡縮で自分自身も動くため、キャンバス固定空間で translation を測る (振動防止)
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.canvasSpaceName))
            .onChanged { value in
                if handleContext?.id != id {
                    guard let start = viewModel.layers.first(where: { $0.id == id }) else { return }
                    handleContext = (id: id, start: start, snapshot: viewModel.layers)
                }
                guard let context = handleContext, canvasSize.width > 0 else { return }
                let start = context.start
                // 中心 (固定点) からの距離の変化率 = 拡縮率 (回転していても安定)
                let centerX = (start.x + start.w / 2) * canvasSize.width
                let centerY = (start.y + start.h / 2) * canvasSize.height
                let startDist = hypot(value.startLocation.x - centerX, value.startLocation.y - centerY)
                guard startDist > 1 else { return }
                let newDist = hypot(value.location.x - centerX, value.location.y - centerY)
                viewModel.scale(id, from: start, factor: newDist / startDist)
            }
            .onEnded { _ in
                if let context = handleContext {
                    viewModel.commitGesture(snapshot: context.snapshot)
                }
                handleContext = nil
            }
    }

    // ドラッグ移動: 開始時の rect を基準に平行移動
    private func dragGesture(for id: String, canvasSize: CGSize) -> some Gesture {
        // レイヤーは .position で動くため、キャンバス固定空間で translation を測る (振動防止)
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.canvasSpaceName))
            .onChanged { value in
                if dragContext?.id != id {
                    guard let start = viewModel.layers.first(where: { $0.id == id }) else { return }
                    dragContext = (id: id, start: start, snapshot: viewModel.layers)
                    viewModel.selectedId = id
                }
                guard let context = dragContext, canvasSize.width > 0 else { return }
                viewModel.move(
                    id,
                    toX: context.start.x + value.translation.width / canvasSize.width,
                    toY: context.start.y + value.translation.height / canvasSize.height
                )
            }
            .onEnded { _ in
                if let context = dragContext {
                    viewModel.commitGesture(snapshot: context.snapshot)
                }
                dragContext = nil
            }
    }

    // ピンチ拡縮: 選択中レイヤーに適用 (キャンバス全体で受ける)
    private func pinchGesture(canvasSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let selectedId = viewModel.selectedId else { return }
                if pinchContext?.id != selectedId {
                    guard let start = viewModel.layers.first(where: { $0.id == selectedId }) else { return }
                    pinchContext = (id: selectedId, start: start, snapshot: viewModel.layers)
                }
                guard let context = pinchContext else { return }
                viewModel.scale(context.id, from: context.start, factor: value.magnification)
            }
            .onEnded { _ in
                if let context = pinchContext {
                    viewModel.commitGesture(snapshot: context.snapshot)
                }
                pinchContext = nil
            }
    }

    // 2本指回転: 選択中レイヤーに適用
    private func rotationGesture() -> some Gesture {
        RotateGesture()
            .onChanged { value in
                guard let selectedId = viewModel.selectedId else { return }
                if rotateContext?.id != selectedId {
                    guard let start = viewModel.layers.first(where: { $0.id == selectedId }) else { return }
                    rotateContext = (id: selectedId, start: start, snapshot: viewModel.layers)
                }
                guard let context = rotateContext else { return }
                viewModel.rotate(context.id, from: context.start, delta: value.rotation.degrees)
            }
            .onEnded { _ in
                if let context = rotateContext {
                    viewModel.commitGesture(snapshot: context.snapshot)
                }
                rotateContext = nil
            }
    }
}

// MARK: - Hex → Color

extension Color {
    /// "#RRGGBB" / "RRGGBB" から Color を作る (不正な文字列は nil)
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}

// MARK: - 編集ツールピル (詳細画面のツール行で使用)

struct OutfitCollageEditPill: View {
    let label: String
    let systemImage: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white)
            .overlay(
                Capsule().stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

// MARK: - Preview

private struct OutfitCollageLayoutCanvasPreview: View {
    @State private var viewModel = OutfitCollageLayoutEditViewModel(client: MockOutfitCollageClient())

    var body: some View {
        VStack {
            OutfitCollageLayoutCanvas(viewModel: viewModel)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(24)
        }
        .background(Color.gray.opacity(0.08))
        .task { await viewModel.load() }
    }
}

#Preview {
    OutfitCollageLayoutCanvasPreview()
}
