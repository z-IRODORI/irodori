//
//  ToastView.swift
//  irodori
//

import SwiftUI

struct ToastView: View {
    let message: String
    var style: ToastStyle = .error

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style == .error ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style == .error ? Color.red : Color.black)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Previews

#Preview("コンポーネント") {
    VStack(spacing: 16) {
        ToastView(message: "通信エラーが発生しました")
        ToastView(message: "データの読み込みに失敗しました。しばらく経ってから再度お試しください。")
        ToastView(message: "アイテムを保存しました", style: .normal)
        ToastView(message: "コーデの配置を保存しました", style: .normal)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.08))
}

#Preview("アニメーション確認") {
    @Previewable @State var isShowing = false

    ZStack(alignment: .top) {
        // 背景（実際のアプリ画面を想定）
        Color.gray.opacity(0.08)
            .ignoresSafeArea()

        VStack {
            Spacer()
            Button(action: {
                guard !isShowing else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isShowing = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation(.easeIn(duration: 0.25)) {
                        isShowing = false
                    }
                }
            }) {
                Text("エラーを表示")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(25)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }

        // トースト
        if isShowing {
            ToastView(message: "通信エラーが発生しました")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
        }
    }
}
