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
    @StateObject private var cameraViewModel: CameraViewModel = .init()
    @State private var showCapturedImage = false

    var body: some View {
        ZStack {
            switch cameraViewModel.cameraState {
            case .initial:
                Color.black
                Text("カメラ準備中...")
                    .foregroundColor(.white)

            case .connectedDevice:
                Color.white

                VStack(spacing: 32) {
                    Text("IRODORI")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.top, 80)
                    CameraPreviewViewRepresentable(cameraViewModel: cameraViewModel)
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    CaptureButton()
                }
                .frame(maxHeight: .infinity, alignment: .top)

            case .noDevice, .error:
                Color.red.opacity(0.6)
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
                    .fill(Color.gray)
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 60, height: 60)
            }
        }
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

