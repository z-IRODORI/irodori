//
//  CameraView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/20.
//

import SwiftUI
import AVFoundation

// メインカメラView
struct CameraView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var showCapturedImage = false

    var body: some View {
        ZStack {
            switch cameraViewModel.cameraState {
            case .initial:
                Color.black
                Text("カメラ準備中...")
                    .foregroundColor(.white)

            case .connectedDevice:
                VStack(spacing: 100) {
                    Spacer()
                    CameraPreviewView(cameraViewModel: cameraViewModel)
                        .aspectRatio(3/4, contentMode: .fit)
                }
                CameraOverlayView()
                CaptureButton()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 60)

            case .noDevice, .error:
                Color.red.opacity(0.6)
                CameraOverlayView()
                CaptureButton()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 60)
            }
        }
        .navigationBarBackButtonHidden()
        .ignoresSafeArea()
        .onAppear {
            checkCameraPermission()   // カメラを初期化
        }
        .fullScreenCover(isPresented: $showCapturedImage) {
            if let image = cameraViewModel.capturedImage {
                CapturedImageView(image: image, isPresented: $showCapturedImage)   // キャプチャした画像表示画面
            }
        }
    }
}

extension CameraView {
    private func CaptureButton() -> some View {
        Button(action: {
            cameraViewModel.capturePhoto()
            // キャプチャ成功後に画像表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if cameraViewModel.capturedImage != nil {
                    showCapturedImage = true
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)

                Circle()
                    .stroke(Color.gray, lineWidth: 2)
                    .frame(width: 60, height: 60)
            }
        }
    }

    private func CameraOverlayView() -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            RoundedRectangle(cornerRadius: 15)
                .frame(width: 360 * 0.85, height: 640 * 0.85)
                .blendMode(.destinationOut)
            Text("全身が映るよう撮影してください")
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .padding(.bottom, 640 * 0.85 + 50)   // くり抜きの上に文字が配置されるよ
        }
        .compositingGroup()
    }
}

extension CameraView {
    // カメラのパーミッション確認
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraViewModel.setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        cameraViewModel.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            print("カメラへのアクセスが拒否されています")
        @unknown default:
            break
        }
    }
}


#Preview {
    CameraView()
}

