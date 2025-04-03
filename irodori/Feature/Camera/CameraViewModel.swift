//
//  CameraViewModel.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import UIKit
import AVFoundation

enum CameraState {
    case initial
    case noDevice
    case connectedDevice
    case error
}

class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var isFlashOn = false
    @Published var cameraState: CameraState = .initial

    // カメラセットアップ
    func setupCamera() {
        do {
            self.session.beginConfiguration()
            self.session.sessionPreset = .iFrame1280x720

            // デバイス設定
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.cameraState = .noDevice
                print("カメラデバイスが見つかりません")
                return
            }

            // 入力設定
            let input = try AVCaptureDeviceInput(device: device)

            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            // 出力設定
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }

            self.session.commitConfiguration()

            // バックグラウンドでカメラセッションを開始
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.session.startRunning()

                DispatchQueue.main.async {
                    self?.cameraState = .connectedDevice
                }
            }
        } catch {
            self.cameraState = .error
            print("カメラセットアップエラー: \(error.localizedDescription)")
        }
    }

    // 写真撮影
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()

        // フラッシュ設定
        if self.isFlashOn && self.output.supportedFlashModes.contains(.on) {
            settings.flashMode = .on
        }

        self.output.capturePhoto(with: settings, delegate: self)
    }

    // カメラセッション停止
    func stopSession() {
        self.session.stopRunning()
    }
}

// 写真キャプチャデリゲート
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("写真処理エラー: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("画像データの取得に失敗しました")
            return
        }

        // キャプチャ画像を長方形にトリミングする
        DispatchQueue.main.async {
            //guard let croppedUIImage = UIImage(data: imageData)?.crop(to: CGSize(width: 400, height: 300)) else { return }
            self.capturedImage = UIImage(data: imageData)
        }
    }
}

