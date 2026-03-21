//
//  CameraView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/20.
//

import SwiftUI
import AVFoundation
import Photos

// メインカメラView
struct CameraView: View {
    @State var cameraViewModel: CameraViewModel
    @Binding var path: [ViewType]
    @State private var showCapturedImage = false
    @State private var isShowOnboardingModal: Bool = false
    var onPhotoCaptured: ((UIImage) -> Void)? = nil

    var body: some View {
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
//                    PartnerComment(image: .wolf, text: Comment.selectedTips())
//                        .padding(.horizontal, 12)
//                        .padding(.top, -80)

                    ZStack(alignment: .center) {
                        PhotoLibraryButton()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 24)
                        CaptureButton()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

            // .connectedDevice との差分はキャプチャ領域がピンク色背景になるだけ
            case .noDevice, .error:
                Color.white
                VStack(spacing: 32) {
                    Header()
                        .padding(.top, 80)
                        .padding(.horizontal, 24)

                    Color.pink
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
//                    PartnerComment(image: .wolf, text: Comment.selectedTips())
//                        .padding(.horizontal, 12)
//                        .padding(.top, -80)

                    ZStack(alignment: .center) {
                        PhotoLibraryButton()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 24)
                        CaptureButton()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
//        .navigationBarBackButtonHidden()
        .ignoresSafeArea()
        .onAppear {
            AnalyticsLogger.shared.log(screen: .cameraScreenView)
            checkCameraPermission()   // カメラを初期化
        }
        .fullScreenCover(isPresented: $showCapturedImage) {
            if let image = cameraViewModel.capturedImage {
                CapturedImageView(
                    image: image,
                    viewModel: .init(inputUIImage: image),
                    isPresented: $showCapturedImage,
                    okButtonTapped: {
                        if let onPhotoCaptured = onPhotoCaptured {
                            // FirstTakePhotoView から呼ばれた場合
                            onPhotoCaptured(image)
                        } else {
                            // 通常のカメラから呼ばれた場合
                            path.append(.coordinateReview(.init(image: image, fromFirstTakePhotoView: false)))
                        }
                    }
                )   // キャプチャした画像表示画面
            }
        }
        .sheet(isPresented: $isShowOnboardingModal) {
            OnboardingView(closeButtonTapped: {
                isShowOnboardingModal = false
            })
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $cameraViewModel.showImagePicker) {
            PhotoPickerView(
                isPresented: $cameraViewModel.showImagePicker,
                onImageSelected: { image in
                    cameraViewModel.processPickedImage(image)
                    // 画像ロード完了後、短い遅延でCapturedImageViewを表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCapturedImage = true
                    }
                },
                onLoadingStateChanged: { isLoading in
                    cameraViewModel.setImageLoadingState(isLoading)
                },
                onError: { errorMessage in
                    cameraViewModel.setImageLoadError(errorMessage)
                }
            )
        }
        .alert("フォトライブラリへのアクセス", isPresented: $cameraViewModel.showPhotoLibraryPermissionAlert) {
            Button("設定") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("写真を選択するには、設定でフォトライブラリへのアクセスを許可してください。")
        }
        .alert("エラー", isPresented: .constant(cameraViewModel.imageLoadError != nil)) {
            Button("OK") {
                cameraViewModel.imageLoadError = nil
            }
        } message: {
            if let errorMessage = cameraViewModel.imageLoadError {
                Text(errorMessage)
            }
        }
        .overlay {
            if cameraViewModel.isLoadingPickedImage {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("画像を読み込んでいます...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .onChange(of: showCapturedImage) { _, isShowing in
            if !isShowing {
                // CapturedImageViewが閉じられたら画像をクリア
                cameraViewModel.capturedImage = nil
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
                    AnalyticsLogger.shared.log(action: .calendarDateSelected, parameters: [
                        "source": GAEventAction.cameraHeaderButton.rawValue
                    ])
                    path.append(.calendar)
                }) {
                    Image(systemName: "calendar")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(.black)
                }

                Button(action: {
                    AnalyticsLogger.shared.log(screen: .onboardingScreenView, parameters: [
                        "source": GAEventAction.helpButton.rawValue
                    ])
                    isShowOnboardingModal = true
                }) {
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(.black)
                }

                // TODO: リリース時は削除
//                Button(action: {
//                    cameraViewModel.earserButtonTapped()
//                    exit(0)
//                }) {
//                    Image(systemName: "eraser")
//                        .resizable()
//                        .frame(width: 20, height: 20)
//                        .foregroundStyle(.black)
//                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
    }

    private func PartnerComment(image: ImageResource, text: String) -> some View {
        HStack(spacing: 0) {
            PartnerIconImage(size: 50)

            SpeechBubbleView(text: text)
        }
    }
}

extension CameraView {
    private func PhotoLibraryButton() -> some View {
        Button(action: {
            AnalyticsLogger.shared.log(action: .photoSelected, parameters: [
                "source": GAEventAction.photoLibrary.rawValue
            ])
            cameraViewModel.checkPhotoLibraryPermission()
        }) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 80, height: 80)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 30))
                    .foregroundColor(.black)
            }
        }
    }
    
    private func CaptureButton() -> some View {
        Button(action: {
            AnalyticsLogger.shared.log(action: .photoTaken, parameters: [
                "source": GAEventAction.camera.rawValue,
                "camera_state": "\(cameraViewModel.cameraState)"
            ])
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
    CameraView(cameraViewModel: .init(), path: .constant([]))
}

