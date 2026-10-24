//
//  PhotoZoomViewer.swift
//  irodori
//
//  コーデ写真・アイテム画像を全画面で見るビューア (ピンチで拡大・拡大中はドラッグで移動・ダブルタップで切替)。
//  画像に .photoZoomOnTap(url:) を付けると、タップでこのビューアが開く。
//

import Kingfisher
import SwiftUI

struct PhotoZoomViewer: View {
    enum Source {
        case url(String)
        case image(UIImage)
    }

    let source: Source
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .onTapGesture { dismiss() }

            photo
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { v in scale = min(max(lastScale * v, 1), 4) }
                        .onEnded { _ in
                            lastScale = scale
                            if scale <= 1 { resetPosition() }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { v in
                            guard scale > 1 else { return }
                            offset = CGSize(width: lastOffset.width + v.translation.width,
                                            height: lastOffset.height + v.translation.height)
                        }
                        .onEnded { v in
                            if scale > 1 {
                                lastOffset = offset
                            } else if v.translation.height > 120 {
                                dismiss()  // 等倍のときは下にスワイプで閉じる
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if scale > 1 {
                            scale = 1
                            resetPosition()
                        } else {
                            scale = 2.5
                        }
                        lastScale = scale
                    }
                }
                .padding(.horizontal, 8)
                .accessibilityLabel("コーデ写真。ピンチで拡大")
        }
        .overlay(alignment: .topTrailing) {
            CloseCircleButton(tint: .white, fill: .white.opacity(0.18)) { dismiss() }
                .padding(.top, 8)
                .padding(.trailing, 10)
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private var photo: some View {
        switch source {
        case .url(let s):
            if let url = URL(string: s) {
                KFImage(url)
                    .placeholder { ProgressView().tint(.white) }
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "photo").font(.system(size: 40)).foregroundStyle(.gray)
            }
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func resetPosition() {
        offset = .zero
        lastOffset = .zero
    }
}

private struct PhotoZoomOnTap: ViewModifier {
    let source: PhotoZoomViewer.Source?
    @State private var showing = false

    func body(content: Content) -> some View {
        if let source {
            content
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptic.impact(.soft)
                    showing = true
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("タップで大きく見る")
                .fullScreenCover(isPresented: $showing) {
                    PhotoZoomViewer(source: source)
                }
        } else {
            content
        }
    }
}

extension View {
    /// タップで写真を全画面ビューアで開く (URL が空なら何もしない)
    func photoZoomOnTap(url: String?) -> some View {
        modifier(PhotoZoomOnTap(source: (url?.isEmpty == false) ? .url(url!) : nil))
    }

    /// タップで写真を全画面ビューアで開く (端末内の画像)
    func photoZoomOnTap(image: UIImage?) -> some View {
        modifier(PhotoZoomOnTap(source: image.map { .image($0) }))
    }
}
