//
//  TryOnFaceSettingCard.swift
//  irodori
//
//  プロフィール画面用: 試着用の顔写真の登録状態カード。
//  タップで再登録 (FaceRegistrationSheet)、登録済みならゴミ箱で削除できる。
//  カードの見た目は ProfileView.itemReplaceEntryCard に合わせている。
//

import SwiftUI

struct TryOnFaceSettingCard: View {
    @State private var thumb: UIImage?
    @State private var isRegistered = false
    @State private var showRegistrationSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Haptic.impact(.soft)
                showRegistrationSheet = true
            } label: {
                HStack(spacing: 12) {
                    faceIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text("試着用の顔写真")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                        Text(isRegistered
                             ? "登録済み・この端末にのみ保存されています"
                             : "未登録・タップして登録すると試着できます")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(isRegistered ? "変更" : "登録")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isRegistered {
                Button {
                    Haptic.impact(.soft)
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .onAppear { refresh() }
        .sheet(isPresented: $showRegistrationSheet) {
            FaceRegistrationSheet(onRegistered: {
                showRegistrationSheet = false
                refresh()
                ToastManager.shared.show("顔写真を更新しました", style: .normal)
            })
        }
        .confirmationDialog(
            "試着用の顔写真を削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                FaceImageStore.shared.deleteAll()
                refresh()
                ToastManager.shared.show("顔写真を削除しました", style: .normal)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("端末内の顔写真と試着結果のキャッシュを削除します。")
        }
    }

    @ViewBuilder
    private var faceIcon: some View {
        if let thumb {
            Image(uiImage: thumb)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.07), lineWidth: 1))
        } else {
            Image(systemName: "person.crop.circle.dashed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func refresh() {
        isRegistered = FaceImageStore.shared.isRegistered
        thumb = FaceImageStore.shared.thumbnail()
    }
}

#Preview("顔写真設定カード") {
    VStack {
        TryOnFaceSettingCard()
        Spacer()
    }
    .padding(.top, 40)
    .background(Color.white)
}
