//
//  ChatView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
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
        HStack(alignment: .bottom, spacing: 12) {
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
            
            Text(message.text)
                .font(.system(size: 16))
                .foregroundColor(message.isUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isUser ? Color.blue : Color.gray.opacity(0.1))
                )
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - ChatView

struct ChatView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "こんにちは！今日のコーディネートはどうですか？", isUser: false),
        ChatMessage(text: "とても素敵だと思います！", isUser: true),
        ChatMessage(text: "ありがとうございます。このトップスとボトムスの組み合わせは、カジュアルながらも上品さを演出していますね。", isUser: false),
        ChatMessage(text: "色のバランスも考えてみました", isUser: true),
        ChatMessage(text: "素晴らしい！配色のセンスが光っていますね。全体的に統一感があって、とてもおしゃれです。", isUser: false)
    ]
    
    @State private var inputText: String = ""
    @State private var suggestedQuestions: [String] = [
        "この色の組み合わせはどう？",
        "もっとカジュアルにするには？",
        "他のアイテムを追加するなら？",
        "季節に合ってる？",
        "どんな場面で着れる？"
    ]
    
    var body: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack(spacing: 0) {
                    // コーデ画像
                    Image("coordinate-1")
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    
                    // チャットメッセージ
                    VStack(spacing: 8) {
                        ForEach(messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
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
            .onChange(of: messages.count) { _ in
                withAnimation {
                    scrollViewProxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 下部固定エリア（キーボード対応）
            VStack(spacing: 0) {
                Divider()
                
                // 質問候補
                SuggestedQuestionsView(
                    questions: suggestedQuestions,
                    onQuestionTapped: { question in
                        inputText = question
                    }
                )
                
                // テキスト入力フィールド
                ChatInputView(
                    text: $inputText,
                    onSend: sendMessage
                )
            }
            .background(.ultraThinMaterial)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // ユーザーメッセージを追加
        let userMessage = ChatMessage(text: inputText, isUser: true)
        messages.append(userMessage)
        
        // 入力をクリア
        inputText = ""
        
        // ここでAIレスポンスを取得する処理を追加（実装例）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let aiResponse = ChatMessage(
                text: "なるほど、いいアイデアですね！そのアプローチでコーディネートをより魅力的にできると思います。",
                isUser: false
            )
            messages.append(aiResponse)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
