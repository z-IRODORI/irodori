//
//  SwipeToDismiss.swift
//  irodori
//
//  トーストを指でスワイプして閉じる。上に出るトーストは上へ、下に出るトーストは下へ払うと閉じる。
//  横に払っても閉じる (どちらの向きでも消せるように)。少しだけ動かしたときは元の位置に戻す。
//

import SwiftUI

private struct SwipeToDismiss: ViewModifier {
    /// トーストが出ている端 (.top / .bottom)。この向きに払うと閉じる
    let edge: VerticalEdge
    let onDismiss: () -> Void

    @State private var drag: CGSize = .zero
    private let threshold: CGFloat = 40

    func body(content: Content) -> some View {
        content
            .offset(x: drag.width, y: drag.height)
            .opacity(1 - min(0.6, Double(abs(drag.width) + abs(drag.height)) / 200.0))
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        let dy = value.translation.height
                        // 端の向きにはそのまま、逆向きには少しだけ動かす
                        let towardEdge = edge == .top ? min(0, dy) : max(0, dy)
                        let away = (edge == .top ? max(0, dy) : min(0, dy)) * 0.2
                        drag = CGSize(width: value.translation.width, height: towardEdge + away)
                    }
                    .onEnded { value in
                        let dy = edge == .top ? -value.translation.height : value.translation.height
                        let dx = abs(value.translation.width)
                        if dy > threshold || dx > threshold * 2 {
                            Haptic.impact(.soft)
                            onDismiss()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drag = .zero }
                    }
            )
            .accessibilityAction(named: "閉じる") { onDismiss() }
    }
}

extension View {
    /// スワイプで閉じられるトーストにする (edge: トーストが出ている端)
    func swipeToDismiss(edge: VerticalEdge, onDismiss: @escaping () -> Void) -> some View {
        modifier(SwipeToDismiss(edge: edge, onDismiss: onDismiss))
    }
}
