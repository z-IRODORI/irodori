//
//  UserInfoView.swift
//  irodori
//
//  Created by Claude on 2025/07/07.
//

import SwiftUI

struct UserInfoView: View {
    let viewModel: UserInfoViewModel
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case year, month, day
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // ヘッダー
            VStack(spacing: 12) {
                Text("IRODORI")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                
                Text("プロフィール情報")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.top, 60)
            
            // フォーム
            VStack(spacing: 24) {
                // ユーザー名入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("ユーザー名")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    TextField("ユーザー名を入力してください", text: Bindable(viewModel).username)
                        .font(.system(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // 誕生日入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("誕生日")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 8) {
                        // 年入力
                        TextField("YYYY", text: Bindable(viewModel).yearInput)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 16, weight: .medium))
                            .frame(height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .year)
                            .onChange(of: viewModel.yearInput) { _, newValue in
                                viewModel.updateYearInput(newValue)
                                if newValue.count == 4 {
                                    focusedField = .month
                                }
                            }

                        // 月入力
                        TextField("MM", text: Bindable(viewModel).monthInput)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 16, weight: .medium))
                            .frame(height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .month)
                            .onChange(of: viewModel.monthInput) { _, newValue in
                                viewModel.updateMonthInput(newValue)
                                if newValue.count == 2 {
                                    focusedField = .day
                                }
                            }

                        // 日入力
                        TextField("DD", text: Bindable(viewModel).dayInput)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 16, weight: .medium))
                            .frame(height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .day)
                            .onChange(of: viewModel.dayInput) { _, newValue in
                                viewModel.updateDayInput(newValue)
                                if newValue.count == 2 {
                                    focusedField = nil // キーボードを閉じる
                                }
                            }
                    }
                }
                
                // 性別選択
                VStack(alignment: .leading, spacing: 8) {
                    Text("性別")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 12) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Button(action: {
                                viewModel.selectedGender = gender
                            }) {
                                Text(gender.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.selectedGender == gender ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(viewModel.selectedGender == gender ? Color.black : Color.gray.opacity(0.1))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(viewModel.selectedGender == gender ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // 完了ボタン
            Button(action: {
                viewModel.saveUserInfo()
            }) {
                Text("完了")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.isFormValid ? Color.black : Color.gray)
                    .cornerRadius(25)
            }
            .disabled(!viewModel.isFormValid)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .ignoresSafeArea()
        .onAppear {
            focusedField = .year
        }
        .onTapGesture {
            // 背景タップでキーボードを閉じる
            focusedField = nil
        }
    }
}

#Preview {
    UserInfoView(viewModel: UserInfoViewModel())
}
