//
//  TryOnEntryModifier.swift
//  irodori
//
//  試着ボタンから試着画面までの共通フロー。
//  顔登録済み → fullScreenCover(TryOnView) / 未登録 → sheet(FaceRegistrationSheet)
//  → 登録完了でそのまま試着へ続行する。
//
//  使い方: 設置面のセクションルートに 1 つだけ付ける (ForEach 内に置かない)。
//      @State private var tryOnSource: TryOnSource?
//      SomeSection(...).tryOnFlow(source: $tryOnSource)
//      Button("試着") { tryOnSource = .snap(...) }
//

import SwiftUI

extension View {
    func tryOnFlow(source: Binding<TryOnSource?>) -> some View {
        modifier(TryOnFlowModifier(source: source))
    }
}

private struct TryOnFlowModifier: ViewModifier {
    @Binding var source: TryOnSource?

    @State private var registrationSource: TryOnSource?
    @State private var activeSource: TryOnSource?

    func body(content: Content) -> some View {
        content
            .onChange(of: source) { _, newValue in
                guard let newValue else { return }
                source = nil
                if FaceImageStore.shared.isRegistered {
                    activeSource = newValue
                } else {
                    registrationSource = newValue
                }
            }
            .sheet(item: $registrationSource) { pending in
                FaceRegistrationSheet(onRegistered: {
                    registrationSource = nil
                    // シートが閉じるアニメーションを待ってから全画面カバーを出す
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSource = pending
                    }
                })
            }
            .fullScreenCover(item: $activeSource) { active in
                TryOnView(source: active, onChangeFace: {
                    // SAFETY などで顔写真を変えたいとき: 登録シートへ戻し、完了後に再試着
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        registrationSource = active
                    }
                })
            }
    }
}
