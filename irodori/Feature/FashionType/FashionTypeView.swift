//
//  FashionTypeView.swift
//  irodori
//
//  Created by Claude on 2026/03/09.
//

import SwiftUI

struct FashionTypeView: View {
    @Binding var path: [ViewType]
    @State var viewModel: FashionTypeViewModel

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            header
                .padding(.horizontal, 24)
                .padding(.top, 12)

            // 進捗バー
            progressBar
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Spacer()

            // 質問エリア
            questionArea
                .padding(.horizontal, 24)

            Spacer()

            // スコア選択エリア
            scoreSelectionArea
                .padding(.horizontal, 24)

            Spacer()

            // ボトムエリア（戻るボタン or 完了ボタン）
            bottomArea
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    path.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                }
            }
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Text("ファッションタイプ診断")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)

            Text("全10問 / 各5段階評価")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)

                    // 進捗
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geometry.size.width * viewModel.progress, height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 6)

            Text("\(viewModel.currentQuestionIndex + 1) / \(FashionTypeQuestion.questions.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
    }

    private var questionArea: some View {
        VStack(spacing: 24) {
            // 質問文
            Text(viewModel.currentQuestion.text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .id("question-\(viewModel.currentQuestion.id)")

            // 例文
            Text(viewModel.currentQuestion.exampleText)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
    }

    private var scoreSelectionArea: some View {
        VStack(spacing: 16) {
            Text("あてはまる度合いを選択してください")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)

            HStack(alignment: .center, spacing: 12) {
                ForEach(1...5, id: \.self) { score in
                    ScoreButton(
                        score: score,
                        isSelected: viewModel.selectedScore == score,
                        action: {
                            viewModel.selectScore(score)
                        }
                    )
                }
            }

            // ラベル
            HStack {
                Text("全く\nあてはまらない")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.pink)
                    .multilineTextAlignment(.center)

                Spacer()

                Text("とても\nあてはまる")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var bottomArea: some View {
        HStack(spacing: 16) {
            // 戻るボタン
            if viewModel.canGoBack {
                Button(action: {
                    viewModel.goToPreviousQuestion()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(25)
                }
            }

            // 次へボタン（最後の質問以外で表示）
            if !viewModel.isLastQuestion {
                Button(action: {
                    viewModel.goToNextQuestion()
                }) {
                    HStack {
                        Text("次へ")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(viewModel.canProceed ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.canProceed ? Color.black : Color.gray.opacity(0.1))
                    .cornerRadius(25)
                }
                .disabled(!viewModel.canProceed)
            }

            // 完了ボタン（最後の質問で表示）
            if viewModel.isLastQuestion {
                Button(action: {
                    Task {
                        if let response = await viewModel.complete() {
                            path.append(.fashionTypeResult(response))
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(25)
                    } else {
                        Text("完了")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(viewModel.canProceed ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(viewModel.canProceed ? Color.black : Color.gray.opacity(0.1))
                            .cornerRadius(25)
                    }
                }
                .disabled(!viewModel.canProceed || viewModel.isLoading)
            }
        }
    }
}

// MARK: - Score Button Component

struct ScoreButton: View {
    let score: Int
    let isSelected: Bool
    let action: () -> Void

    private var buttonSize: CGFloat {
        switch score {
        case 1, 5:
            return 60  // 大
        case 2, 4:
            return 50  // 中
        case 3:
            return 40  // 小
        default:
            return 50
        }
    }

    private var fontSize: CGFloat {
        switch score {
        case 1, 5:
            return 20
        case 2, 4:
            return 18
        case 3:
            return 16
        default:
            return 18
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? Color.black : Color.gray.opacity(0.2))
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Text("\(score)")
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .gray)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
    }
}

#Preview {
    @Previewable @State var path: [ViewType] = []
    NavigationStack(path: $path) {
        FashionTypeView(path: $path, viewModel: FashionTypeViewModel())
    }
}
