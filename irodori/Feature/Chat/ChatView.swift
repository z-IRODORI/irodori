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
                Image("wolf")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
                    .clipShape(Circle())
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
    @State private var isScrolledToBottom: Bool = true
    
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
        let imageData = image.jpegData(compressionQuality: 1.0)!
        self.viewModel = .init(coordinateId: coordinateId, coordinateImageBase64: imageData.base64EncodedString(), apiClient: HomeClient(), repository: CoordinateChatRepository())
    }
    
    var body: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack(spacing: 0) {
                    // コーデ画像
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fit)
                        .frame(maxWidth: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 24)

                    // チャットメッセージ
                    VStack(spacing: 8) {
                        ForEach(viewModel.coordinateChat.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack {
                                Image("wolf")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.gray.opacity(0.1)))
                                    .clipShape(Circle())

                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                    Text("考え中...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
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
                    .padding(.vertical, 20)

                    // 下部スペースを確保（id "bottom"でスクロール位置の基準に）
                    Color.clear
                        .frame(height: 20)
                        .id("bottom")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.coordinateChat.messages.count) { _ in
                withAnimation {
                    scrollViewProxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .overlay(
                // 下へスクロールボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                scrollViewProxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20) // 質問候補の上に配置
                    }
                },
                alignment: .bottomTrailing
            )
        }
        .safeAreaInset(edge: .bottom) {
            // 下部固定エリア（キーボード対応）
            VStack(spacing: 0) {
                Divider()

                // 質問候補
                SuggestedQuestionsView(
                    questions: suggestedQuestions,
                    onQuestionTapped: { question in
                        viewModel.addSuggestedQuestion(question)
                    }
                )

                // テキスト入力フィールド
                ChatInputView(
                    text: $viewModel.inputText,
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                )
            }
            .background(.ultraThinMaterial)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadCoordinateChat()
        }
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
