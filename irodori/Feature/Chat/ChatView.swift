//
//  ChatView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import SwiftUI

struct ChatMessage: Identifiable, Codable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(text: String, isUser: Bool) {
        self.id = UUID().uuidString
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
    }

    init(id: String, text: String, isUser: Bool, timestamp: Date) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - SuggestedQuestionsView

struct SuggestedQuestionsView: View {
    let questions: [String]
    let onQuestionTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 質問候補のラベル
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                Text("質問候補")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(questions, id: \.self) { question in
                        Button(action: { onQuestionTapped(question) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text(question)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.blue.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 44)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.gray.opacity(0.03))
    }
}

// MARK: - ChatInputView

struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack {
                TextField("メッセージを入力", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .onSubmit { onSend() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(24)

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(text.isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4) // 下部の余白を調整
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - ChatBubbleView

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                PartnerIconImage(size: 40)
            }

            Text(.init(message.text))
                .font(.system(size: 14))
                .foregroundColor(message.isUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isUser ? Color.blue : Color.gray.opacity(0.1))
                )
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser {
                Spacer(minLength: 30)
            }
        }
        .padding(.trailing, 16)
        .padding(.leading, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - ChatView

struct ChatView: View {
    @State var viewModel: ChatViewModel
    @State private var showMiniImage: Bool = false
    @State private var showScrollConfirmation: Bool = false

    private let suggestedQuestions: [String] = [
        "この色の組み合わせはどう？",
        "もっとカジュアルにするには？",
        "他のアイテムを追加するなら？",
        "季節に合ってる？",
        "どんな場面で着れる？"
    ]

    let image: UIImage
    init(coordinateId: String, image: UIImage) {
        self.image = image
        let resizedImage = ChatView.resizeImage(image, targetWidth: 800)
        let imageData = resizedImage.jpegData(compressionQuality: 0.3)!
        self.viewModel = .init(
            coordinateId: coordinateId,
            coordinateImageBase64: imageData.base64EncodedString(),
            apiClient: ChatClient(),
            repository: CoordinateChatRepository()
        )
    }

    private static func resizeImage(_ image: UIImage, targetWidth: CGFloat) -> UIImage {
        let scale = targetWidth / image.size.width
        let newSize = CGSize(width: targetWidth, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? image
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // コーデ画像
                    GeometryReader { geo in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fit)
                            .frame(maxWidth: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                            .frame(maxWidth: .infinity)
                            .id("coordinateImage")
                            .onAppear { showMiniImage = false }
                            .onChange(of: geo.frame(in: .global).maxY) { newValue in
                                showMiniImage = newValue < 0
                            }
                    }
                    .frame(height: 270)
                    .padding(.top, 16)

                    // メッセージ
                    if viewModel.isLoadingHistory {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 8) {
                            let messagesSnapshot = Array(viewModel.coordinateChat.messages.enumerated())
                            ForEach(messagesSnapshot, id: \.element.id) { index, message in
                                let showDate = index == 0 || !Calendar.current.isDate(
                                    message.timestamp,
                                    inSameDayAs: messagesSnapshot[index - 1].element.timestamp
                                )
                                if showDate {
                                    ChatDateSeparatorView(date: message.timestamp)
                                }
                                CoordinateChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    PartnerIconImage(size: 40)
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(0.8)
                                        Text("考え中...")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    Spacer(minLength: 60)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 12)
                    }

                    Color.clear.frame(height: 20).id("bottom")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: viewModel.coordinateChat.messages.count) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .overlay(alignment: .topLeading) {
                if showMiniImage {
                    Button(action: { showScrollConfirmation = true }) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fit)
                            .frame(width: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 12)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                    .alert("画像まで移動しますか？", isPresented: $showScrollConfirmation) {
                        Button("キャンセル", role: .cancel) {}
                        Button("移動") {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo("coordinateImage", anchor: .top)
                            }
                        }
                    } message: {
                        Text("コーディネート画像の位置まで戻りますか？")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showMiniImage)
        }
        .background(.white)
        .navigationTitle("コーデについて相談する")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                GeneralSuggestedQuestionsView(
                    questions: suggestedQuestions,
                    onQuestionTapped: { viewModel.addSuggestedQuestion($0) }
                )
                GeneralChatInputView(
                    text: $viewModel.inputText,
                    onSend: { Task { await viewModel.sendMessage() } }
                )
            }
            .background(.ultraThinMaterial)
        }
        .onAppear {
            viewModel.loadCoordinateChat()
        }
    }
}

// MARK: - CoordinateChatBubbleView
// GeneralChatBubbleView と同構造。ユーザーバブルをインディゴに変更してコーデ相談と汎用チャットを視覚的に区別

struct CoordinateChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                PartnerIconImage(size: 40)
            }

            Text(.init(message.text))
                .font(.system(size: 14))
                .foregroundStyle(message.isUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isUser ? Color.indigo : Color.gray.opacity(0.1))
                )
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser {
                Spacer(minLength: 30)
            }
        }
        .padding(.trailing, 16)
        .padding(.leading, 8)
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ChatView(
            coordinateId: "preview-coordinate",
            image: UIImage(resource: .coordinate7)
        )
    }
}
