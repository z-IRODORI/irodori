//
//  EdgeSwipeToClose.swift
//  irodori
//
//  ナビゲーションバーを隠した画面 (カメラなど) で、左端から右へのスワイプで閉じられるようにする。
//  標準の「戻る」スワイプはナビゲーションバーを隠すと効かなくなるため、左端に細い受け口を置いて代わりにする。
//

import SwiftUI

private struct EdgeSwipeToClose: ViewModifier {
    let onClose: () -> Void
    /// 指を置ける左端の幅
    private let edgeWidth: CGFloat = 24
    /// これ以上右へ動かしたら閉じる
    private let threshold: CGFloat = 80

    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .overlay(alignment: .leading) {
                Color.clear
                    .frame(width: edgeWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .global)
                            .onChanged { value in
                                offset = max(0, value.translation.width)
                            }
                            .onEnded { value in
                                let shouldClose = value.translation.width > threshold
                                    || value.predictedEndTranslation.width > threshold * 2
                                if shouldClose {
                                    Haptic.impact(.soft)
                                    onClose()
                                }
                                withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                            }
                    )
                    .accessibilityHidden(true)
            }
    }
}

extension View {
    /// 左端から右へスワイプすると onClose を呼ぶ (ナビゲーションバーを隠した画面用)
    func edgeSwipeToClose(_ onClose: @escaping () -> Void) -> some View {
        modifier(EdgeSwipeToClose(onClose: onClose))
    }
}
