//
//  MultiPhotoPickerView.swift
//  irodori
//
//  写真フォルダから複数枚の画像を選択する PHPicker ラッパー。
//  既存の単一選択 PhotoPickerView とは別に、コラージュ用の複数選択に使う。
//

import SwiftUI
import PhotosUI

struct MultiPhotoPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var selectionLimit: Int = 0  // 0 = 無制限
    let onImagesSelected: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiPhotoPickerView

        init(_ parent: MultiPhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false

            let providers = results.map { $0.itemProvider }
            guard !providers.isEmpty else { return }

            // 選択順を保持するため index 付きで読み込む
            var loaded = [Int: UIImage]()
            let group = DispatchGroup()

            for (index, provider) in providers.enumerated() where provider.canLoadObject(ofClass: UIImage.self) {
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        loaded[index] = image
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                let images = loaded.keys.sorted().compactMap { loaded[$0] }
                self.parent.onImagesSelected(images)
            }
        }
    }
}
