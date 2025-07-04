//
//  CameraPreviewView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI
import AVFoundation

// カメラのプレビュー表示用View
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraViewModel: CameraViewModel

    func makeUIView(context: Context) -> UIView {
        return updateAVCaptureVideoPreviewLayer()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    /// キャプチャ画面を生成し画面へ追加する
    private func updateAVCaptureVideoPreviewLayer() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraViewModel.session)

        // 縦向きの場合
        if view.bounds.width < view.bounds.height {
            let previewWidth = view.bounds.width
            let previewHeight = previewWidth * (4 / 3)
            previewLayer.frame = .init(x: 0, y: 0, width: previewWidth, height: previewHeight)
        } else {
            let previewHeight = view.bounds.height
            let previewWidth = previewHeight * (3 / 4)
            previewLayer.frame = .init(x: 0, y: 0, width: previewWidth, height: previewHeight)
        }
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        return view
    }
}
