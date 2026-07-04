//
//  OutfitCollageLayoutEditView.swift
//  irodori
//
//  クローゼットでコーデの配置編集画面 (シート表示)。
//  サーバーが用意した透過レイヤー PNG を 3:4 キャンバスに重ね、
//  ドラッグで移動・ピンチで拡大縮小・ボタンで重なり順を変更できる。
//  「この配置で保存」でサーバーが同じレイアウトで再合成し、
//  ホーム/詳細のコラージュ画像 (collage_url) が差し替わる。
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

    private(set) var collageId = ""
    private var defaultLayers: [OutfitCollageLayoutItem] = []
    private var baseline: [OutfitCollageLayoutItem] = []
    private var undoStack: [[OutfitCollageLayoutItem]] = []
    private let maxUndoCount = 20

    // 拡縮の上下限 (正規化)。小さすぎて掴めない/大きすぎて破綻するのを防ぐ
    private let minSide = 0.06
    private let maxSide = 1.4

    private let client: OutfitCollageClientProtocol
    init(client: OutfitCollageClientProtocol = OutfitCollageClient()) {
        self.client = client
    }

    var hasChanges: Bool { layers != baseline }
    var canUndo: Bool { !undoStack.isEmpty }
    var canReset: Bool { layers != defaultLayers }
    var selectedLayer: OutfitCollageLayoutItem? { layers.first { $0.id == selectedId } }

    /// 選択中レイヤーが最前面/最背面か (前面へ/背面へ ボタンの活性判定)
    var selectedIsTop: Bool {
        guard let sel = selectedLayer else { return true }
        return sel.z == layers.map(\.z).max()
    }
    var selectedIsBottom: Bool {
        guard let sel = selectedLayer else { return true }
        return sel.z == layers.map(\.z).min()
    }

    func load() async {
        isLoading = true
        loadFailed = false
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

    // MARK: 編集操作 (ジェスチャー中は snapshot を渡さず直接更新し、確定時に commit する)

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
        let maxFactor = min(maxSide / start.w, maxSide / start.h)
        let minFactor = max(minSide / start.w, minSide / start.h)
        guard minFactor <= maxFactor else { return }
        let f = min(max(factor, minFactor), maxFactor)
        let newW = start.w * f
        let newH = start.h * f
        layers[index].x = start.x + (start.w - newW) / 2
        layers[index].y = start.y + (start.h - newH) / 2
        layers[index].w = newW
        layers[index].h = newH
    }

    /// ジェスチャー確定。開始時 snapshot と差分があれば undo に積む
    func commitGesture(snapshot: [OutfitCollageLayoutItem]) {
        guard layers != snapshot else { return }
        pushUndo(snapshot)
    }

    func bringForward(_ id: String) {
        swapZWithNeighbor(id, offset: 1)
    }

    func sendBackward(_ id: String) {
        swapZWithNeighbor(id, offset: -1)
    }

    /// z 順で隣のレイヤーと z を入れ替える (1段ずつ前面/背面へ)
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
    }

    private func pushUndo(_ snapshot: [OutfitCollageLayoutItem]) {
        undoStack.append(snapshot)
        if undoStack.count > maxUndoCount {
            undoStack.removeFirst()
        }
    }

    // MARK: 保存

    func save() async -> OutfitCollageResponse? {
        guard hasChanges, !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        do {
            switch try await client.saveLayout(uid: uid, gender: gender, collageId: collageId, items: layers) {
            case .success(let response):
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

// MARK: - View

struct OutfitCollageLayoutEditView: View {
    @State var viewModel = OutfitCollageLayoutEditViewModel()
    let onSaved: (OutfitCollageResponse) -> Void

    @Environment(\.dismiss) private var dismiss

    // ジェスチャー中の一時状態 (開始時のレイヤー状態と undo 用スナップショット)
    @State private var dragContext: (id: String, start: OutfitCollageLayoutItem, snapshot: [OutfitCollageLayoutItem])?
    @State private var pinchContext: (id: String, start: OutfitCollageLayoutItem, snapshot: [OutfitCollageLayoutItem])?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(.black)
                        Text("アイテムを準備しています")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.loadFailed {
                    loadErrorView
                } else {
                    editView
                }
            }
            .navigationTitle("配置を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
        .task { await viewModel.load() }
        .overlay {
            if viewModel.isSaving {
                savingOverlay
            }
        }
    }

    // MARK: 編集

    private var editView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("アイテムをタップして選択。ドラッグで移動、ピンチで大きさを変えられます。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                canvas
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )

                zOrderRow
                toolRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer(minLength: 0)
        }
        .background(Color.gray.opacity(0.05))
        .safeAreaInset(edge: .bottom) { ctaBar }
    }

    // レイヤーを重ねる編集キャンバス
    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                // 何もない場所のタップで選択解除
                Color.white
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedId = nil }

                ForEach(viewModel.layers) { layer in
                    layerView(layer, canvasSize: geo.size)
                }
            }
            .clipped()
            .simultaneousGesture(pinchGesture(canvasSize: geo.size))
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
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            .contentShape(Rectangle())
            .position(
                x: (layer.x + layer.w / 2) * canvasSize.width,
                y: (layer.y + layer.h / 2) * canvasSize.height
            )
            .zIndex(Double(layer.z))
            .onTapGesture {
                Haptic.impact(.soft)
                viewModel.selectedId = layer.id
            }
            .gesture(dragGesture(for: layer.id, canvasSize: canvasSize))
    }

    // ドラッグ移動: 開始時の rect を基準に平行移動
    private func dragGesture(for id: String, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
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

    // 重なり順 (選択中のみ活性)
    private var zOrderRow: some View {
        HStack(spacing: 8) {
            if let selected = viewModel.selectedLayer {
                Text(slotDisplayName(selected.slot))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("アイテム未選択")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            toolButton(
                label: "前面へ",
                systemImage: "square.2.layers.3d.top.filled",
                disabled: viewModel.selectedLayer == nil || viewModel.selectedIsTop
            ) {
                if let id = viewModel.selectedId { viewModel.bringForward(id) }
            }
            toolButton(
                label: "背面へ",
                systemImage: "square.2.layers.3d.bottom.filled",
                disabled: viewModel.selectedLayer == nil || viewModel.selectedIsBottom
            ) {
                if let id = viewModel.selectedId { viewModel.sendBackward(id) }
            }
        }
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            toolButton(
                label: "元に戻す",
                systemImage: "arrow.uturn.backward",
                disabled: !viewModel.canUndo
            ) {
                viewModel.undo()
            }
            toolButton(
                label: "リセット",
                systemImage: "arrow.counterclockwise",
                disabled: !viewModel.canReset
            ) {
                viewModel.resetToDefault()
            }
            Spacer(minLength: 0)
        }
    }

    private func toolButton(
        label: String,
        systemImage: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
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

    private func slotDisplayName(_ slot: String) -> String {
        switch slot {
        case "tops": return "トップスを選択中"
        case "bottoms": return "ボトムスを選択中"
        case "outer": return "アウターを選択中"
        case "shoes": return "シューズを選択中"
        case "bag": return "バッグを選択中"
        case "accessory": return "アクセサリーを選択中"
        default: return "選択中"
        }
    }

    // MARK: 保存 CTA

    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptic.impact(.medium)
                Task {
                    if let response = await viewModel.save() {
                        onSaved(response)
                        ToastManager.shared.show("コーデの配置を保存しました")
                        dismiss()
                    }
                }
            } label: {
                Text("この配置で保存")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(viewModel.hasChanges ? Color.black : Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!viewModel.hasChanges || viewModel.isSaving)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.white)
    }

    // MARK: エラー / 保存中

    private var loadErrorView: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 24))
                .foregroundStyle(Color.gray.opacity(0.5))
            Text("アイテムを読み込めませんでした")
                .font(.system(size: 14, weight: .semibold))
            Button {
                Task { await viewModel.load() }
            } label: {
                Text("再試行する")
                    .font(.system(size: 13))
                    .foregroundStyle(.black)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("保存中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
        }
    }
}

#Preview {
    OutfitCollageLayoutEditView(
        viewModel: .init(client: MockOutfitCollageClient()),
        onSaved: { _ in }
    )
}
