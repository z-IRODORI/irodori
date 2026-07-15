//
//  PhoneAuthView.swift
//  irodori
//
//  電話番号 (SMS認証) による会員登録/ログイン画面。
//  ステップ1: 電話番号入力 -> ステップ2: 6桁認証コード入力
//

import SwiftUI

struct PhoneAuthView: View {
    @State private var viewModel = PhoneAuthViewModel()
    let onSignInSuccess: () -> Void

    @FocusState private var isPhoneNumberFieldFocused: Bool
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.step {
            case .phoneNumber:
                phoneNumberStep
            case .verificationCode:
                verificationCodeStep
            }
        }
        .background(Color.white)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isLoading)
        .animation(.easeInOut(duration: 0.25), value: viewModel.step)
    }

    // MARK: - ステップ1: 電話番号入力

    private var phoneNumberStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("電話番号で登録・ログイン")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)

                Text("SMSで6桁の認証コードをお送りします。")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 8) {
                Text("携帯電話番号")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)

                TextField("090-1234-5678", text: Bindable(viewModel).phoneNumberText)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .font(.system(size: 20, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isPhoneNumberFieldFocused ? Color.black : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isPhoneNumberFieldFocused)
                    .onChange(of: viewModel.phoneNumberText) { _, newValue in
                        viewModel.formatPhoneNumberText(newValue)
                    }

                Text("日本の携帯電話番号（090 / 080 / 070 / 060）に対応しています。")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.top, 32)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.top, 12)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.sendCode()
                        if viewModel.step == .verificationCode {
                            isCodeFieldFocused = true
                        }
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("認証コードを送信")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.isPhoneNumberValid ? Color.black : Color.gray)
                    .cornerRadius(25)
                }
                .disabled(!viewModel.isPhoneNumberValid || viewModel.isLoading)

                Text("電話番号は本人確認のためだけに使用します。")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .onAppear {
            isPhoneNumberFieldFocused = true
        }
    }

    // MARK: - ステップ2: 認証コード入力

    private var verificationCodeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.backToPhoneNumberStep()
                isPhoneNumberFieldFocused = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("電話番号を変更")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.gray)
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("認証コードを入力")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)

                Text("\(viewModel.phoneNumberText) 宛に6桁のコードを送信しました。")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.top, 24)

            codeInputBoxes
                .padding(.top, 32)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.top, 12)
            }

            HStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.trailing, 4)
                    Text("確認中…")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                } else if viewModel.canResend {
                    Button {
                        Task { await viewModel.resendCode() }
                    } label: {
                        Text("認証コードを再送信")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .underline()
                    }
                } else {
                    Text("認証コードを再送信（\(viewModel.resendRemainingSeconds)秒後）")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 24)

            Spacer()
        }
        .padding(.horizontal, 20)
        .onAppear {
            isCodeFieldFocused = true
        }
    }

    /// 6桁コードの入力欄 (非表示の TextField + 表示用ボックス)
    private var codeInputBoxes: some View {
        ZStack {
            TextField("", text: Bindable(viewModel).codeText)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundColor(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .focused($isCodeFieldFocused)
                .onChange(of: viewModel.codeText) { _, newValue in
                    viewModel.formatCodeText(newValue)
                    if viewModel.codeText.count == PhoneAuthViewModel.codeLength {
                        Task {
                            if await viewModel.verifyCode() {
                                onSignInSuccess()
                            }
                        }
                    }
                }

            HStack(spacing: 8) {
                ForEach(0..<PhoneAuthViewModel.codeLength, id: \.self) { index in
                    let characters = Array(viewModel.codeText)
                    let isCurrent = index == viewModel.codeText.count && isCodeFieldFocused
                    Text(index < characters.count ? String(characters[index]) : "")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isCurrent ? Color.black : Color.gray.opacity(0.3), lineWidth: isCurrent ? 1.5 : 1)
                        )
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isCodeFieldFocused = true
        }
    }
}

#Preview {
    PhoneAuthView(onSignInSuccess: {})
}
