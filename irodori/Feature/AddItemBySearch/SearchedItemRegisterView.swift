//
//  SearchedItemRegisterView.swift
//  irodori
//
//  検索で選んだ画像を確認 (背景除去済み) し、属性を付けてクローゼットに登録する。
//  UI は ItemImageEditView と同じミニマル言語 (白背景・黒の主CTA・ピル型)。
//

import SwiftUI

// 属性編集のサジェスト候補 (タップで入力欄にセット。自由入力も可能)
private let topsCategorySuggestions = ["Tシャツ", "シャツ", "ニット", "セーター", "パーカー", "スウェット", "カーディガン", "ブラウス"]
private let bottomsCategorySuggestions = ["パンツ", "ジーンズ", "ワイドパンツ", "スラックス", "チノパン", "ショートパンツ", "スカート", "スウェットパンツ"]
private let colorSuggestions = ["ブラック", "ホワイト", "グレー", "ネイビー", "ベージュ", "ブラウン", "カーキ", "ブルー", "グリーン", "レッド", "イエロー", "ピンク"]

struct SearchedItemRegisterView: View {
    @State var viewModel: SearchedItemRegisterViewModel
    let onRegistered: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.loadFailed {
                    loadErrorView
                } else {
                    editView
                }
            }
            .navigationTitle("アイテムを登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .disabled(viewModel.isRegistering)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isRegistering)
        .task { await viewModel.load() }
        .overlay { if viewModel.isRegistering { savingOverlay } }
    }

    // MARK: - 編集

    private var editView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("背景を自動で透明にしました。内容を確認して、種類・カテゴリ・カラーを整えて登録してください。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                imagePreview
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )

                if !viewModel.backgroundRemoved {
                    Button {
                        Task { await viewModel.retryRemoveBackground() }
                    } label: {
                        Label("背景除去をやり直す", systemImage: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .overlay(Capsule().stroke(Color.black.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                attributesSection

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.gray.opacity(0.05))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { registerCtaBar }
    }

    private var imagePreview: some View {
        Group {
            if let image = viewModel.workingImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                Color.gray.opacity(0.1)
            }
        }
    }

    // MARK: - 属性編集

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

    // MARK: - 登録CTA

    private var registerCtaBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptic.impact(.medium)
                Task {
                    if await viewModel.register() {
                        onRegistered()
                        dismiss()
                    }
                }
            } label: {
                Text("クローゼットに登録")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(viewModel.canRegister ? Color.black : Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!viewModel.canRegister)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.white)
    }

    // MARK: - エラー / 登録中

    private var loadErrorView: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 24))
                .foregroundStyle(Color.gray.opacity(0.5))
            Text("画像を読み込めませんでした")
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
                Text("登録中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
        }
    }
}
