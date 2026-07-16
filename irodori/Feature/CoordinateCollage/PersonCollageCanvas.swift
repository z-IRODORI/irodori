//
//  PersonCollageCanvas.swift
//  irodori
//
//  コーデコラージュの編集キャンバス (OutfitCollageLayoutCanvas と同じ操作体系 + 回転)。
//  結果画面のコラージュ表示そのものが編集キャンバスになる:
//   - タップ = 選択 + 最前面へ / 余白タップ = 選択解除
//   - ドラッグ = 移動 (中心がキャンバス内に収まるようクランプ)
//   - ピンチ = 拡大縮小 (中心固定・アスペクト維持)
//   - 2本指回転 = 回転
//   - 右下の◯ハンドル = 中心固定の拡大縮小 (回転していても安定)
//  背景色・ロゴ・人物ステッカーは PersonCollageEngine.compose と同じ見た目で描画する
//  (WYSIWYG: ここで見えるものがそのまま保存される)。
//

import SwiftUI

struct PersonCollageCanvas: View {
    let viewModel: CoordinateCollageViewModel

    @State private var dragContext: (id: String, start: PersonCollageLayer, snapshot: [PersonCollageLayer])?
    @State private var pinchContext: (id: String, start: PersonCollageLayer, snapshot: [PersonCollageLayer])?
    @State private var rotateContext: (id: String, start: PersonCollageLayer, snapshot: [PersonCollageLayer])?
    @State private var handleContext: (id: String, start: PersonCollageLayer, snapshot: [PersonCollageLayer])?

    // レイヤーは .position で動くため、キャンバス固定空間で translation を測る (振動防止)
    private static let canvasSpaceName = "personCollageCanvas"

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景色 (余白タップで選択解除)
                viewModel.backgroundColor
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedLayerId = nil }

                // IRODORI ロゴ (上部固定・編集不可)
                logoView(canvasSize: geo.size)

                ForEach(viewModel.visibleLayers) { layer in
                    layerView(layer, canvasSize: geo.size)
                }
            }
            .clipped()
            .coordinateSpace(name: Self.canvasSpaceName)
            .simultaneousGesture(pinchGesture())
            .simultaneousGesture(rotationGesture())
        }
    }

    private func logoView(canvasSize: CGSize) -> some View {
        let logoName = PersonCollageEngine.preferredLogoName(for: UIColor(viewModel.backgroundColor))
        let width = canvasSize.width * 0.56
        return Image(logoName)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .position(x: canvasSize.width / 2, y: canvasSize.height * 0.04 + logoHeight(width: width) / 2)
            .allowsHitTesting(false)
    }

    private func logoHeight(width: CGFloat) -> CGFloat {
        guard let logo = UIImage(named: "logo-black") else { return 0 }
        return width * logo.size.height / max(1, logo.size.width)
    }

    private func layerView(_ layer: PersonCollageLayer, canvasSize: CGSize) -> some View {
        let width = layer.w * canvasSize.width
        let height = layer.h * canvasSize.height
        let isSelected = viewModel.selectedLayerId == layer.id

        return Group {
            if let sticker = viewModel.stickerImages[layer.id] {
                Image(uiImage: sticker).resizable()
            } else {
                Color.gray.opacity(0.08)
            }
        }
        .frame(width: width, height: height)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.black.opacity(0.55), lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.impact(.soft)
            viewModel.selectedLayerId = layer.id
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

    // 右下のリサイズハンドル: 中心からの距離の変化率で拡縮 (回転していても安定)
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
        .contentShape(Circle().inset(by: -10))
        .gesture(handleDragGesture(for: id, canvasSize: canvasSize))
    }

    private func handleDragGesture(for id: String, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.canvasSpaceName))
            .onChanged { value in
                if handleContext?.id != id {
                    guard let start = viewModel.collageLayers.first(where: { $0.id == id }) else { return }
                    handleContext = (id: id, start: start, snapshot: viewModel.collageLayers)
                }
                guard let context = handleContext, canvasSize.width > 0 else { return }
                let start = context.start
                // 中心 (固定点) からの距離の変化率 = 拡縮率
                let centerX = (start.x + start.w / 2) * canvasSize.width
                let centerY = (start.y + start.h / 2) * canvasSize.height
                let startDist = hypot(value.startLocation.x - centerX, value.startLocation.y - centerY)
                guard startDist > 1 else { return }
                let newDist = hypot(value.location.x - centerX, value.location.y - centerY)
                viewModel.scaleLayer(id, from: start, factor: newDist / startDist)
            }
            .onEnded { _ in
                if let context = handleContext {
                    viewModel.commitGesture(snapshot: context.snapshot)
                }
                handleContext = nil
            }
    }

    private func dragGesture(for id: String, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.canvasSpaceName))
            .onChanged { value in
                if dragContext?.id != id {
                    guard let start = viewModel.collageLayers.first(where: { $0.id == id }) else { return }
                    dragContext = (id: id, start: start, snapshot: viewModel.collageLayers)
                    viewModel.selectedLayerId = id
                }
                guard let context = dragContext, canvasSize.width > 0 else { return }
                viewModel.moveLayer(
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
    private func pinchGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let selectedId = viewModel.selectedLayerId else { return }
                if pinchContext?.id != selectedId {
                    guard let start = viewModel.collageLayers.first(where: { $0.id == selectedId }) else { return }
                    pinchContext = (id: selectedId, start: start, snapshot: viewModel.collageLayers)
                }
                guard let context = pinchContext else { return }
                viewModel.scaleLayer(context.id, from: context.start, factor: value.magnification)
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
                guard let selectedId = viewModel.selectedLayerId else { return }
                if rotateContext?.id != selectedId {
                    guard let start = viewModel.collageLayers.first(where: { $0.id == selectedId }) else { return }
                    rotateContext = (id: selectedId, start: start, snapshot: viewModel.collageLayers)
                }
                guard let context = rotateContext else { return }
                viewModel.rotateLayer(context.id, from: context.start, delta: value.rotation.degrees)
            }
            .onEnded { _ in
                if let context = rotateContext {
                    viewModel.commitGesture(snapshot: context.snapshot)
                }
                rotateContext = nil
            }
    }
}
