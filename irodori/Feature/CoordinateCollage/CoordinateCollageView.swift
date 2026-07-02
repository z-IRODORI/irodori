//
//  CoordinateCollageView.swift
//  irodori
//
//  コーデコラージュ生成画面。
//  入力(コーデ3枚以上 + 背景色) → ローディング → 結果(シェア/保存/別パターン) の
//  3ステップを 1 画面で管理する。
//
//  UI は IRODORI デザインシステム (OutfitSuggestionView と同じ) に従う:
//   - 白背景・モノトーン・余白主役（カード/影/グラデは使わない）
//   - 選択 = 黒、非選択 = 白 + hairline ボーダー
//   - CTA は黒・下部固定
//

import SwiftUI
import Kingfisher

struct CoordinateCollageView: View {
    @State var viewModel: CoordinateCollageViewModel
    @Binding var path: [ViewType]
    @State private var showPhotoPicker = false

    private let presetColors: [Color] = [
        Color(red: 1.0, green: 140.0 / 255.0, blue: 66.0 / 255.0),   // オレンジ
        Color(red: 17.0 / 255.0, green: 24.0 / 255.0, blue: 39.0 / 255.0),  // ダーク
        Color(red: 37.0 / 255.0, green: 99.0 / 255.0, blue: 235.0 / 255.0), // ブルー
        Color(red: 236.0 / 255.0, green: 72.0 / 255.0, blue: 153.0 / 255.0), // ピンク
        Color(red: 16.0 / 255.0, green: 185.0 / 255.0, blue: 129.0 / 255.0), // グリーン
        Color(white: 0.96)                                            // オフホワイト
    ]
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ZStack {
            switch viewModel.step {
            case .input:
                inputView
            case .loading:
                loadingView
            case .result:
                resultView
            }
        }
        .navigationTitle("コーデコラージュ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.white, for: .navigationBar)
        .animation(.easeInOut(duration: 0.22), value: viewModel.step)
        .task { await viewModel.loadRegisteredCoordinates() }
        .sheet(isPresented: $showPhotoPicker) {
            MultiPhotoPickerView(isPresented: $showPhotoPicker) { images in
                viewModel.addPickedImages(images)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: 入力

    private var inputView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("コーデを3枚以上えらんで、1枚のシェア画像をつくります。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.horizontal, 4)

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                // 登録コーデから選ぶ
                section("登録コーデからえらぶ", note: selectionNote) {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.isLoadingCoordinates {
                            ProgressView()
                                .tint(.black)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 12)
                        } else if viewModel.registeredCoordinates.isEmpty {
                            emptyText("登録済みのコーデがまだありません。下の「写真から追加」でえらんでください")
                        } else {
                            LazyVGrid(columns: gridColumns, spacing: 8) {
                                ForEach(viewModel.registeredCoordinates) { coordinate in
                                    coordinateThumbnail(coordinate)
                                }
                            }
                        }
                    }
                }

                // 写真から追加
                section("写真から追加", note: "任意") {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            Haptic.impact(.soft)
                            showPhotoPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 15))
                                Text("写真フォルダからえらぶ")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        if !viewModel.pickedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(viewModel.pickedImages.enumerated()), id: \.offset) { index, image in
                                        pickedImageTile(image, index: index)
                                    }
                                }
                            }
                        }
                    }
                }

                // 背景色
                section("背景色") {
                    FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(Array(presetColors.enumerated()), id: \.offset) { _, color in
                            colorSwatch(color)
                        }
                        ColorPicker("", selection: $viewModel.backgroundColor)
                            .labelsHidden()
                            .frame(width: 44, height: 44)
                    }
                }

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .background(Color.gray.opacity(0.05))
        .safeAreaInset(edge: .bottom) { ctaBar }
    }

    private var selectionNote: String {
        viewModel.totalSelectedCount > 0 ? "選択中 \(viewModel.totalSelectedCount)枚" : "3枚以上"
    }

    // セクション: 白カード + hairline ボーダー (OutfitSuggestionView と同じ)
    private func section<Content: View>(
        _ title: String,
        note: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(.primary)
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            content()
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

    // 登録コーデのサムネイル (3:4)。選択 = 黒ボーダー + チェックマーク
    private func coordinateThumbnail(_ coordinate: CoordinateCollageViewModel.RegisteredCoordinate) -> some View {
        let isSelected = viewModel.selectedCoordinateIDs.contains(coordinate.id)
        return Button {
            Haptic.impact(.soft)
            viewModel.toggleCoordinate(coordinate.id)
        } label: {
            Color.clear
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay(
                    ZStack {
                        Color.gray.opacity(0.12)
                        KFImage(URL(string: coordinate.url))
                            .resizable()
                            .scaledToFill()
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.black : Color.black.opacity(0.07), lineWidth: isSelected ? 2 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .black)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // 写真フォルダから選んだ画像タイル (削除ボタンは 44pt のヒット領域)
    private func pickedImageTile(_ image: UIImage, index: Int) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 84, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    Haptic.impact(.soft)
                    viewModel.removePickedImage(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .padding(4)
                        .frame(width: 44, height: 44, alignment: .topTrailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
    }

    // 背景色スウォッチ (44pt タップ領域、選択 = 黒リング)
    private func colorSwatch(_ color: Color) -> some View {
        let isSelected = viewModel.backgroundColor.toHexString() == color.toHexString()
        return Button {
            Haptic.impact(.soft)
            viewModel.backgroundColor = color
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 40, height: 40)
                }
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 13))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    // 下部固定 CTA（黒）。3枚未満のときは残り枚数を表示
    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptic.impact(.medium)
                viewModel.generate()
            } label: {
                Text(viewModel.canGenerate ? "コラージュを作る" : "あと\(viewModel.remainingCount)枚えらんでください")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.canGenerate ? Color.black : Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!viewModel.canGenerate)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.white)
    }

    // MARK: ローディング

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.black)
            VStack(spacing: 6) {
                Text("コラージュを作成しています")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("人物を切り抜いて1枚に合成しています")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            Button {
                Haptic.impact(.soft)
                viewModel.cancelGeneration()
            } label: {
                Text("キャンセル")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(Color.black.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    // MARK: 結果

    private var resultView: some View {
        ScrollView(showsIndicators: false) {
            if let image = viewModel.resultImage {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("できあがり")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.generatedImageCount > 0 {
                            Text("\(viewModel.generatedImageCount)枚のコーデから作成")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // コラージュ本体 (シャッフル中は上に半透明オーバーレイ)
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
                            )
                        if viewModel.isShuffling {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.35))
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)
                                Text("別のパターンを作成中…")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    // シェア / 保存
                    HStack(spacing: 10) {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("コーデコラージュ", image: Image(uiImage: image))
                        ) {
                            Label("シェアする", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button {
                            Haptic.impact(.soft)
                            viewModel.saveResultToPhotos()
                        } label: {
                            Label("保存する", systemImage: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // 別パターン (同じ選択のまま配置だけ変える)
                    Button {
                        Haptic.impact(.soft)
                        Task { await viewModel.shuffle() }
                    } label: {
                        Label("別パターンで作る", systemImage: "shuffle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isShuffling)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button {
                    Haptic.impact(.soft)
                    viewModel.backToInput()
                } label: {
                    Text("条件を変えて作り直す")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .background(.white)
        }
    }
}
