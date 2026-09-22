//
//  DeviceSettingCard.swift
//  irodori
//
//  プロフィール画面用: 玄関カメラ (Raspberry Pi) 連携への入口カード。
//  見た目は TryOnFaceSettingCard に合わせている。タップで DeviceSetupView へ push。
//

import SwiftUI

struct DeviceSettingCard: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptic.impact(.soft)
            onTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("玄関カメラ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("玄関に置くだけで、毎朝のコーデを自動で記録")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    VStack {
        DeviceSettingCard(onTap: {})
        Spacer()
    }
    .padding(.top, 40)
    .background(Color.white)
}
