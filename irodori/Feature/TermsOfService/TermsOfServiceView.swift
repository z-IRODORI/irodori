//
//  TermsOfServiceView.swift
//  irodori
//
//  Created by Claude on 2025/07/06.
//

import SwiftUI

struct TermsOfServiceView: View {
    @StateObject private var viewModel = TermsOfServiceViewModel()
    @State private var showingAlert = false
    
    var body: some View {
        VStack(spacing: 24) {
            // ヘッダー
            VStack(spacing: 16) {
                Text("IRODORI")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)

                Text("利用規約への同意")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.top, 40)

            // 利用規約内容
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    /// 変数に格納された文字列をマークダウン形式で表示する
                    /// マークダウンテキストがコードに直接存在しない場合 (例えば、変数から、または保存された値から読み取られる場合)、マークダウンとしてレンダリングする必要がある。
                    Text(LocalizedStringKey(viewModel.loadTermsOfService()))
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 24)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 20)

            // ボタン
            VStack(spacing: 16) {
                Button(action: {
                    viewModel.agreeToTerms()
                }) {
                    Text("同意する")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: {
                    showingAlert = true
                }) {
                    Text("同意しない")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
        .background(Color.white)
        .alert("アプリを終了", isPresented: $showingAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("終了", role: .destructive) {
                viewModel.exitApp()
            }
        } message: {
            Text("利用規約に同意いただけない場合、アプリを終了します。")
        }
    }
}

#Preview {
    TermsOfServiceView()
}
