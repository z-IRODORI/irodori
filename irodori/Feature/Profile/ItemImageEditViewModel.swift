//
//  ItemImageEditViewModel.swift
//  irodori
//
//  クローゼットアイテム画像の編集 (ノイズ除去 / 消しゴム) と保存を管理する。
//
//  保存は「新アイテムとして登録 → 成功後に旧アイテムを削除」の差し替え方式。
//  既存の登録 (POST /api/items/register/bulk) と削除 (DELETE /api/items/{id}) の
//  エンドポイントのみを使い、既存の Storage 画像や Firestore ドキュメントは
//  上書きしない (サーバ側の変更も不要)。
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ItemImageEditViewModel {
    enum Step { case edit, confirm }

    let item: ClosetItem

    var step: Step = .edit
    var isLoadingImage = true
    var loadFailed = false
    var originalImage: UIImage?
    var workingImage: UIImage?
    var isRemovingNoise = false
    var isSaving = false

    var hasChanges: Bool { !undoStack.isEmpty }
    var canUndo: Bool { !undoStack.isEmpty }

    private var undoStack: [UIImage] = []
    private let maxUndoCount = 20

    private let registerClient: BulkItemRegisterClientProtocol
    private let deleteClient: DeleteClosetItemClientProtocol

    init(
        item: ClosetItem,
        registerClient: BulkItemRegisterClientProtocol = BulkItemRegisterClient(),
        deleteClient: DeleteClosetItemClientProtocol = DeleteClosetItemClient()
    ) {
        self.item = item
        self.registerClient = registerClient
        self.deleteClient = deleteClient
    }

    func loadImage() async {
        guard originalImage == nil else { return }
        guard let urlString = item.image_url, let url = URL(string: urlString) else {
            loadFailed = true
            isLoadingImage = false
            return
        }
        isLoadingImage = true
        loadFailed = false
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode < 400,
                  let image = UIImage(data: data) else {
                loadFailed = true
                isLoadingImage = false
                return
            }
            // 編集・再アップロードに十分な解像度に抑える (メモリ/通信量)
            let prepared = image.fixedOrientation().resizedToFit(longEdge: 1024)
            originalImage = prepared
            workingImage = prepared
        } catch {
            loadFailed = true
        }
        isLoadingImage = false
    }

    // MARK: - 編集

    func removeNoise() async {
        guard let current = workingImage, !isRemovingNoise else { return }
        isRemovingNoise = true
        defer { isRemovingNoise = false }
        do {
            let cleaned = try await ItemNoiseRemover.removeBackgroundNoise(from: current)
            pushUndo(current)
            workingImage = cleaned
            Haptic.impact(.soft)
        } catch {
            let message = (error as? ItemNoiseRemoverError)?.errorDescription
            ToastManager.shared.show(message ?? "ノイズ除去に失敗しました")
        }
    }

    /// 消しゴム1ストロークを画像に焼き込む。
    /// points / lineWidth は画像座標系 (ピクセル基準のポイント座標)。白 = 背景色で塗る。
    func commitEraserStroke(points: [CGPoint], lineWidth: CGFloat) {
        guard let current = workingImage, !points.isEmpty else { return }

        let format = UIGraphicsImageRendererFormat()
        format.scale = current.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: current.size, format: format)
        let erased = renderer.image { ctx in
            current.draw(in: CGRect(origin: .zero, size: current.size))
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(lineWidth)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.beginPath()
            cg.move(to: points[0])
            if points.count == 1 {
                // タップだけでも丸く消せるようにする (同一点への線は round cap で点になる)
                cg.addLine(to: points[0])
            } else {
                for point in points.dropFirst() {
                    cg.addLine(to: point)
                }
            }
            cg.strokePath()
        }

        pushUndo(current)
        workingImage = erased
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        workingImage = last
    }

    func resetToOriginal() {
        guard let original = originalImage else { return }
        undoStack.removeAll()
        workingImage = original
    }

    private func pushUndo(_ image: UIImage) {
        undoStack.append(image)
        if undoStack.count > maxUndoCount {
            undoStack.removeFirst()
        }
    }

    // MARK: - 確認 / 保存

    func goToConfirm() {
        guard hasChanges else { return }
        step = .confirm
    }

    func backToEdit() {
        step = .edit
    }

    /// 編集後の画像を新アイテムとして登録し、成功したら旧アイテムを削除する (差し替え)。
    /// 成功時は差し替え後の ClosetItem を返す。
    func save() async -> ClosetItem? {
        guard let image = workingImage,
              let data = image.jpegData(compressionQuality: 0.8),
              let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else {
            ToastManager.shared.show("保存に失敗しました")
            return nil
        }
        isSaving = true
        defer { isSaving = false }

        let metadata = BulkItemMetadata(
            index: 0,
            gender: UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue),
            main_category: nil,
            sub_category: nil,
            color: item.color,
            item_type: item.item_type,
            category: item.category,
            coordinate_id: nil
        )

        do {
            let result = try await registerClient.register(
                userId: uid,
                userToken: uid,  // user_token は user_id と同じ値を使用 (SelectStandardItem と同様)
                items: [(metadata: metadata, imageData: data)]
            )
            switch result {
            case .success(let response):
                guard response.success_count >= 1, let registered = response.items.first else {
                    ToastManager.shared.show("保存に失敗しました")
                    return nil
                }
                // 旧アイテムの削除はベストエフォート (失敗しても新画像は保存済み)
                var deletedOldItem = false
                if let deleteResult = try? await deleteClient.delete(uid: uid, itemId: item.id),
                   case .success(let deleteResponse) = deleteResult,
                   deleteResponse.success {
                    deletedOldItem = true
                }
                if !deletedOldItem {
                    ToastManager.shared.show("元の画像が残っています。不要な場合はクローゼットから削除してください")
                }
                return ClosetItem(
                    id: registered.id,
                    item_type: registered.item_type ?? item.item_type,
                    category: registered.category ?? item.category,
                    color: registered.color ?? item.color,
                    image_url: registered.storage_url,
                    date: item.date
                )
            case .failure(let error):
                ToastManager.shared.show(error.errorDescription ?? "保存に失敗しました")
                return nil
            }
        } catch {
            ToastManager.shared.show("保存に失敗しました")
            return nil
        }
    }
}
