//
//  CloseCircleButton.swift
//  irodori
//
//  全画面の画面 (カメラ・写真を探す・相棒の質問・Web など) で使う ✕ ボタン。
//  見た目は 32pt の丸、押せる範囲は 44pt。シートは ✕ ではなくツールバー右の「閉じる」を使う。
//

import SwiftUI

struct CloseCircleButton: View {
    var tint: Color = .black
    var fill: Color = Color.black.opacity(0.06)
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(fill))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("閉じる")
    }
}
