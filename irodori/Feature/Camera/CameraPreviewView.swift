//
//  CameraPreviewView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI
import AVFoundation

// MARK: - Representable

struct CameraPreviewViewRepresentable: UIViewRepresentable {
    @ObservedObject var cameraViewModel: CameraViewModel

    func makeUIView(context: Context) -> UIView {
        return CameraPreviewView(cameraViewModel: cameraViewModel)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 必要があればプレビュー更新処理をここに追加
    }
}

// MARK: - UIView

final class CameraPreviewView: UIView {
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let cameraViewModel: CameraViewModel

    init(cameraViewModel: CameraViewModel) {
        self.cameraViewModel = cameraViewModel
        super.init(frame: .zero)

        previewLayer.session = cameraViewModel.session
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        self.addGestureRecognizer(pinchGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // アスペクト比 4:3 に合わせてサイズ調整
        let isPortrait = bounds.height > bounds.width
        let width = bounds.width
        let height = isPortrait ? width * 4 / 3 : bounds.height
        previewLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
    }

    // TODO: リプレイスして0.5倍拡大できるようにする
    // ピンチでキャプチャを拡大/縮小する
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        if gesture.state == .changed {
            let maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            let pinchVelocityDividerFactor: CGFloat = 5.0

            do {
                try device.lockForConfiguration()
                let desiredZoomFactor = device.videoZoomFactor + atan2(gesture.velocity, pinchVelocityDividerFactor)
                device.videoZoomFactor = max(1.0, min(desiredZoomFactor, maxZoomFactor))
                device.unlockForConfiguration()
            } catch {
                print("⚠️ Zoom error: \(error.localizedDescription)")
            }
        }
    }
}

