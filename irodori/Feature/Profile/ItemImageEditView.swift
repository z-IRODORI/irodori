//
//  ItemImageEditView.swift
//  irodori
//
//  クローゼットアイテム画像の編集画面 (シート表示)。
//  「ノイズ除去」(Vision 被写体マスク) と消しゴム (なぞって透明にする) で画像を整え、
//  確認ステップ「この画像で良いですか？」で OK されたら透過 PNG として保存する。
//
//  自分で直しきれない撮影切り抜きのために、ツールの下に
//  「きれいな商品画像に差し替える」(ItemImageReplaceView) への導線を置く。
//  差し替え後はそのまま新しいアイテムで編集画面を開き直す。
//
//  UI は OutfitSuggestionView と同じミニマル言語:
//  白背景・黒の主CTA・白 + hairline の副CTA・ピル型ツールボタン。
//

import SwiftUI

// 属性編集のサジェスト候補（タップで入力欄にセット。自由入力も可能）
private let topsCategorySuggestions = ["Tシャツ", "シャツ", "ニット", "セーター", "パーカー", "スウェット", "カーディガン", "ブラウス"]
private let bottomsCategorySuggestions = ["パンツ", "ジーンズ", "ワイドパンツ", "スラックス", "チノパン", "ショートパンツ", "スカート", "スウェットパンツ"]
private let colorSuggestions = ["ブラック", "ホワイト", "グレー", "ネイビー", "ベージュ", "ブラウン", "カーキ", "ブルー", "グリーン", "レッド", "イエロー", "ピンク"]

struct ItemImageEditView: View {
    @State var viewModel: ItemImageEditViewModel
    /// 保存・差し替えで別アイテムに置き換わったことを親へ通知する (差し替え前の id を必ず渡す)
    let onSaved: (_ oldId: String, _ newItem: ClosetItem) -> Void

    @Environment(\.dismiss) private var dismiss

    // 消しゴム描画中のストローク (ビュー座標)
    @State private var currentStroke: [CGPoint] = []
    @State private var brushSize: CGFloat = 24

    // 商品画像への差し替え
    @State private var showReplacePicker = false
    @State private var showReplaceConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingImage {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.loadFailed {
                    loadErrorView
                } else {
                    switch viewModel.step {
                    case .edit:
                        editView
                    case .confirm:
                        confirmView
                    }
                }
            }
            .navigationTitle(viewModel.step == .edit ? "アイテムを編集" : "変更の確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
            }
            .navigationDestination(isPresented: $showReplacePicker) {
                ItemImageReplaceView(
                    viewModel: .init(item: viewModel.item),
                    onReplaced: { oldId, newItem in
                        // 差し替えはこの時点でサーバに反映済み。クローゼット一覧へ伝えたうえで、
                        // 戻り先の編集画面も新しいアイテムで開き直す (続けて消しゴム等で微調整できる)
                        onSaved(oldId, newItem)
                        currentStroke = []
                        viewModel = .init(item: newItem)
                        Task { await viewModel.loadImage() }
                    }
                )
            }
            .alert("編集中の内容があります", isPresented: $showReplaceConfirmation) {
                Button("キャンセル", role: .cancel) {}
                Button("差し替えに進む") { showReplacePicker = true }
            } message: {
                Text("商品画像に差し替えると、いまの編集内容は反映されません。")
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
        .task { await viewModel.loadImage() }
        .overlay {
            if viewModel.isSaving {
                savingOverlay
            }
        }
    }

    // MARK: - 編集ステップ

    private var editView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("「ノイズ除去」で背景を自動で透明にできます。気になる部分は消しゴムでなぞって透明にできます（市松模様 = 透明）。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                editorCanvas
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )

                toolRow

                HStack(spacing: 10) {
                    Text("消しゴムの太さ")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Slider(value: $brushSize, in: 10...60)
                        .tint(.black)
                    Circle()
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        .frame(width: brushSize / 2, height: brushSize / 2)
                        .frame(width: 30, height: 30)
                }

                // 撮影切り抜きのアイテムだけに、自分で直しきれないときの逃げ道を出す
                if viewModel.item.isPhotoCropImage {
                    replaceEntryCard
                }

                attributesSection

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.gray.opacity(0.05))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { editCtaBar }
    }

    // MARK: - アイテム情報 (属性編集)

    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("アイテム情報")
                .font(.system(size: 14, weight: .bold))
                .tracking(0.3)

            VStack(alignment: .leading, spacing: 10) {
                attributeLabel("種類")
                HStack(spacing: 8) {
                    ForEach(ClothingCategory.allCases) { type in
                        typeSegment(type.rawValue, selected: viewModel.editedItemType == type.rawValue) {
                            viewModel.editedItemType = type.rawValue
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                attributeLabel("カテゴリ")
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(categorySuggestions, id: \.self) { suggestion in
                        pill(suggestion, selected: viewModel.editedCategory == suggestion) {
                            viewModel.editedCategory = (viewModel.editedCategory == suggestion) ? "" : suggestion
                        }
                    }
                }
                underlineField("入力する（例: モックネックニット）", text: $viewModel.editedCategory)
            }

            VStack(alignment: .leading, spacing: 10) {
                attributeLabel("カラー")
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(colorSuggestions, id: \.self) { suggestion in
                        pill(suggestion, selected: viewModel.editedColor == suggestion) {
                            viewModel.editedColor = (viewModel.editedColor == suggestion) ? "" : suggestion
                        }
                    }
                }
                underlineField("入力する（例: オフホワイト）", text: $viewModel.editedColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    // 種類は選択中のものに合わせたカテゴリ候補を出す
    private var categorySuggestions: [String] {
        viewModel.editedItemType == ClothingCategory.bottoms.rawValue
            ? bottomsCategorySuggestions
            : topsCategorySuggestions
    }

    private func attributeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func typeSegment(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(text)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.black : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.clear : Color.black.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func pill(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(text)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(selected ? Color.black : Color.white)
                .overlay(
                    Capsule().stroke(selected ? Color.clear : Color.black.opacity(0.18), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func underlineField(_ placeholder: String, text: Binding<String>) -> some View {
        VStack(spacing: 7) {
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .tint(.black)
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 1)
        }
    }

    // 画像 + 消しゴム描画キャンバス
    private var editorCanvas: some View {
        GeometryReader { geo in
            if let image = viewModel.workingImage {
                let fitRect = Self.aspectFitRect(imageSize: image.size, in: geo.size)
                ZStack {
                    // 透明部分を可視化する市松模様 (画像の表示領域のみ)
                    CheckerboardBackground()
                        .frame(width: fitRect.width, height: fitRect.height)
                        .position(x: fitRect.midX, y: fitRect.midY)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)

                    // 描画中ストロークのプレビュー (確定時に画像へ焼き込む)
                    Path { path in
                        guard let first = currentStroke.first else { return }
                        path.move(to: first)
                        for point in currentStroke.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: brushSize, lineCap: .round, lineJoin: .round)
                    )

                    // ブラシカーソル
                    if let last = currentStroke.last {
                        Circle()
                            .stroke(Color.black.opacity(0.35), lineWidth: 1)
                            .frame(width: brushSize, height: brushSize)
                            .position(last)
                    }
                }
                .contentShape(Rectangle())
                // ScrollView 内でもキャンバス上のドラッグは消しゴムを優先する
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentStroke.append(value.location)
                        }
                        .onEnded { _ in
                            commitStroke(fitRect: fitRect, imageSize: image.size)
                        }
                )
            }
        }
    }

    private var toolRow: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            toolButton(
                label: viewModel.isRemovingNoise ? "処理中…" : "ノイズ除去",
                systemImage: "sparkles",
                emphasized: true,
                disabled: viewModel.isRemovingNoise || viewModel.isSmoothingEdges
            ) {
                Task { await viewModel.removeNoise() }
            }
            toolButton(
                label: viewModel.isSmoothingEdges ? "処理中…" : "輪郭をなめらか",
                systemImage: "scribble.variable",
                disabled: viewModel.isSmoothingEdges || viewModel.isRemovingNoise
            ) {
                Task { await viewModel.smoothEdges() }
            }
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
                disabled: !viewModel.imageChanged
            ) {
                viewModel.resetToOriginal()
            }
        }
    }

    private func toolButton(
        label: String,
        systemImage: String,
        emphasized: Bool = false,
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
            .foregroundStyle(emphasized ? .white : .black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(emphasized ? Color.black : Color.white)
            .overlay(
                Capsule().stroke(emphasized ? Color.clear : Color.black.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    // MARK: - 商品画像への差し替え導線

    /// ノイズ除去・消しゴムで直しきれないときの別ルート。
    /// 主CTA (保存する) と競合しないよう、副次的なカード + chevron で置く。
    private var replaceEntryCard: some View {
        Button {
            Haptic.impact(.soft)
            // 編集中の内容は差し替えに引き継がれないため、変更がある時だけ確認する
            if viewModel.hasChanges {
                showReplaceConfirmation = true
            } else {
                showReplacePicker = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("きれいな商品画像に差し替える")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("うまく切り抜けないときは、ネットの商品画像から選べます")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.gray.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRemovingNoise || viewModel.isSmoothingEdges)
    }

    private var editCtaBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptic.impact(.medium)
                viewModel.goToConfirm()
            } label: {
                Text("保存する")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(viewModel.hasChanges ? Color.black : Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!viewModel.hasChanges)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.white)
    }

    // MARK: - 確認ステップ

    private var confirmView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("この内容で良いですか？")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.top, 16)

                HStack(alignment: .top, spacing: 12) {
                    comparisonColumn(title: "変更前", image: viewModel.originalImage)
                    // 変更後は保存される最終画像 (透明余白トリム + 正方形再フィット済み) を見せる
                    comparisonColumn(title: "変更後", image: viewModel.finalImage ?? viewModel.workingImage)
                }

                attributeChangesSummary

                Text("保存すると、クローゼットのアイテムがこの内容に差し替わります。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.gray.opacity(0.05))
        .safeAreaInset(edge: .bottom) { confirmCtaBar }
    }

    // アイテム情報の変更前 → 変更後
    private var attributeChangesSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("アイテム情報")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            attributeChangeRow(
                "種類",
                before: viewModel.item.item_type,
                after: viewModel.editedItemType
            )
            attributeChangeRow(
                "カテゴリ",
                before: displayValue(viewModel.item.category),
                after: displayValue(viewModel.editedCategory)
            )
            attributeChangeRow(
                "カラー",
                before: displayValue(viewModel.item.color),
                after: displayValue(viewModel.editedColor)
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    private func attributeChangeRow(_ label: String, before: String, after: String) -> some View {
        let changed = before != after
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(before)
                .font(.system(size: 13))
                .foregroundStyle(changed ? .secondary : .primary)
                .strikethrough(changed)
            if changed {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(after)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
    }

    private func displayValue(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未設定" : trimmed
    }

    private func comparisonColumn(title: String, image: UIImage?) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(CheckerboardBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
            }
        }
    }

    private var confirmCtaBar: some View {
        VStack(spacing: 10) {
            Divider()
            Button {
                Haptic.impact(.medium)
                Task {
                    let oldId = viewModel.item.id
                    if let newItem = await viewModel.save() {
                        onSaved(oldId, newItem)
                        ToastManager.shared.show("アイテムを保存しました", style: .normal)
                        dismiss()
                    }
                }
            } label: {
                Text("この内容で保存")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 20)
            .padding(.top, 2)

            Button {
                Haptic.impact(.soft)
                viewModel.backToEdit()
            } label: {
                Text("編集に戻る")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
            }
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .background(.white)
    }

    // MARK: - 読み込みエラー / 保存中

    private var loadErrorView: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 24))
                .foregroundStyle(Color.gray.opacity(0.5))
            Text("画像を読み込めませんでした")
                .font(.system(size: 14, weight: .semibold))
            Button {
                Task { await viewModel.loadImage() }
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

    // MARK: - 座標変換

    /// ストローク (ビュー座標) を画像座標へ変換して焼き込む
    private func commitStroke(fitRect: CGRect, imageSize: CGSize) {
        defer { currentStroke = [] }
        guard fitRect.width > 0, !currentStroke.isEmpty else { return }
        let scale = imageSize.width / fitRect.width
        let imagePoints = currentStroke.map { point in
            CGPoint(x: (point.x - fitRect.minX) * scale, y: (point.y - fitRect.minY) * scale)
        }
        viewModel.commitEraserStroke(points: imagePoints, lineWidth: brushSize * scale)
    }

    /// アスペクトフィットで表示したときの画像の実表示領域
    private static func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2
        )
        return CGRect(origin: origin, size: size)
    }
}

/// 透明部分を可視化する市松模様の背景
private struct CheckerboardBackground: View {
    var square: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / square))
            let rows = Int(ceil(size.height / square))
            for row in 0..<rows {
                for col in 0..<cols where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(col) * square,
                        y: CGFloat(row) * square,
                        width: square,
                        height: square
                    )
                    context.fill(Path(rect), with: .color(Color.gray.opacity(0.15)))
                }
            }
        }
        .background(Color.white)
    }
}

#Preview {
    ItemImageEditView(
        viewModel: .init(
            item: ClosetItem(
                id: "preview",
                item_type: "トップス",
                category: "Tシャツ",
                color: "ホワイト",
                image_url: "https://example.com/item.jpg",
                date: nil
            ),
            registerClient: MockBulkItemRegisterClient(),
            deleteClient: MockDeleteClosetItemClient()
        ),
        onSaved: { _, _ in }
    )
}
