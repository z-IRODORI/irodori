//
//  CoordinateCollageView.swift
//  irodori
//
//  コーデコラージュ生成画面。
//  登録コーデ (3枚以上) または写真フォルダから画像を選び、背景色を指定して
//  人物を切り抜いて 1 枚に合成した「カッコいいコーデ画像」を生成・表示・保存する。
//

import SwiftUI

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
    private let gridColumns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                coordinateSelectionSection
                photoPickerSection
                backgroundColorSection
                generateButton
                if viewModel.isGenerating {
                    generatingView
                }
                if let image = viewModel.resultImage {
                    resultSection(image)
                }
                if let message = viewModel.errorMessage {
                    errorView(message)
                }
            }
            .padding(20)
        }
        .navigationTitle("コーデコラージュ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadRegisteredCoordinates() }
        .sheet(isPresented: $showPhotoPicker) {
            MultiPhotoPickerView(isPresented: $showPhotoPicker) { images in
                viewModel.addPickedImages(images)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("コーデを3枚以上選んで、\n1枚のカッコいい画像を作ろう")
                .font(.system(size: 18, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("選択中: \(viewModel.totalSelectedCount) 枚（3枚以上で生成できます）")
                .font(.system(size: 13))
                .foregroundStyle(viewModel.totalSelectedCount >= 3 ? .green : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Registered coordinates

    @ViewBuilder
    private var coordinateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("登録済みのコーデ")
                .font(.system(size: 15, weight: .semibold))

            if viewModel.isLoadingCoordinates {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else if viewModel.registeredCoordinates.isEmpty {
                Text("登録済みのコーデがありません。下の「写真から選ぶ」で画像を追加してください")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                if !viewModel.hasEnoughRegisteredCoordinates {
                    Text("登録コーデが3枚未満です。足りない分は「写真から選ぶ」で追加してください")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(viewModel.registeredCoordinates) { coordinate in
                        coordinateThumbnail(coordinate)
                    }
                }
            }
        }
    }

    private func coordinateThumbnail(_ coordinate: CoordinateCollageViewModel.RegisteredCoordinate) -> some View {
        let isSelected = viewModel.selectedCoordinateIDs.contains(coordinate.id)
        return ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: coordinate.url)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ProgressView()
                default:
                    Color.gray.opacity(0.15)
                }
            }
            .frame(width: 96, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor, .white)
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleCoordinate(coordinate.id)
        }
    }

    // MARK: - Photo picker

    private var photoPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("写真から選ぶ")
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.primary)
            }

            if !viewModel.pickedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.pickedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 108)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Button {
                                    viewModel.removePickedImage(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white, .black.opacity(0.5))
                                        .padding(3)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Background color

    private var backgroundColorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("背景色")
                .font(.system(size: 15, weight: .semibold))
            HStack(spacing: 12) {
                ForEach(Array(presetColors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(.gray.opacity(0.3), lineWidth: 1))
                        .onTapGesture { viewModel.backgroundColor = color }
                }
                ColorPicker("", selection: $viewModel.backgroundColor)
                    .labelsHidden()
                Spacer()
            }
        }
    }

    // MARK: - Generate

    private var generateButton: some View {
        Button {
            Task { await viewModel.generate() }
        } label: {
            Text("コラージュを生成")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.canGenerate ? Color.accentColor : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!viewModel.canGenerate)
    }

    private var generatingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("コラージュを作成中…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Result

    private func resultSection(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("完成！")
                .font(.system(size: 15, weight: .semibold))
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                viewModel.saveResultToPhotos()
            } label: {
                HStack {
                    Image(systemName: viewModel.didSaveToPhotos ? "checkmark" : "square.and.arrow.down")
                    Text(viewModel.didSaveToPhotos ? "保存しました" : "画像をダウンロード")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.didSaveToPhotos ? Color.green : Color.black)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.didSaveToPhotos)
        }
    }

    private func errorView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
