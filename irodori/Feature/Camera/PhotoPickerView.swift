//
//  PhotoPickerView.swift
//  irodori
//
//  Created by AI Assistant on 2025/03/22.
//

import SwiftUI
import PhotosUI

struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageSelected: (UIImage) -> Void
    let onLoadingStateChanged: ((Bool) -> Void)?
    let onError: ((String) -> Void)?

    init(
        isPresented: Binding<Bool>,
        onImageSelected: @escaping (UIImage) -> Void,
        onLoadingStateChanged: ((Bool) -> Void)? = nil,
        onError: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.onImageSelected = onImageSelected
        self.onLoadingStateChanged = onLoadingStateChanged
        self.onError = onError
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false

            guard let result = results.first else { return }

            // ローディング開始通知
            DispatchQueue.main.async {
                self.parent.onLoadingStateChanged?(true)
            }

            result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                DispatchQueue.main.async {
                    // ローディング終了通知（成功・失敗に関わらず）
                    self.parent.onLoadingStateChanged?(false)

                    // エラーハンドリング
                    if let error = error {
                        self.parent.onError?("画像の読み込みに失敗しました: \(error.localizedDescription)")
                        return
                    }

                    // 画像取得成功
                    if let image = object as? UIImage {
                        self.parent.onImageSelected(image)
                    } else {
                        self.parent.onError?("画像の形式が正しくありません")
                    }
                }
            }
        }
    }
}