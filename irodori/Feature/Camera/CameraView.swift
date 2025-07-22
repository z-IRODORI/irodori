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
    @State private var path: [ViewType] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                switch cameraViewModel.cameraState {
                case .initial:
                    VStack(spacing: 24) {
                        Text("カメラ準備中...")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.pink)
                        Image(.splash03)
                            .resizable()
                            .frame(width: 200, height: 300)
                    }

                case .connectedDevice:
                    Color.white

                    VStack(spacing: 32) {
                        Header()
                            .padding(.top, 80)
                            .padding(.horizontal, 24)
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
            .navigationDestination(for: ViewType.self) { viewType in
                switch viewType {
                case .calendar:
                    CalendarView(path: $path)
                case .camera:
                    EmptyView()
                }
            }
        }
    }

    private func Header() -> some View {
        ZStack {
            Text("IRODORI")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
            HStack(spacing: 24) {
                Button(action: {
                    path.append(.calendar)
                }) {
                    Image(systemName: "calendar")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.black)
                }

                // TODO: リリース時は削除
                Button(action: {
                    cameraViewModel.earserButtonTapped()
                    exit(0)
                }) {
                    Image(systemName: "eraser")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
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

