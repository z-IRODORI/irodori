import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Binding var path: [ViewType]
    @State private var viewModel: ProfileEditViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(path: Binding<[ViewType]>, profileInfo: ProfileInfo?) {
        self._path = path
        self._viewModel = State(initialValue: ProfileEditViewModel(profileInfo: profileInfo))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileImageSection
                userInfoSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color.white)
        .navigationTitle("プロフィール編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    viewModel.save()
                    path.removeLast()
                }
                .fontWeight(.semibold)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await viewModel.uploadProfileImage(uiImage)
                }
            }
        }
    }

    private var profileImageSection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let url = viewModel.getProfileImageURL() {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty:
                                ProgressView()
                            case .failure:
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.gray.opacity(0.5))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "camera.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .background(Color.white.clipShape(Circle()))
                        .foregroundStyle(.blue)
                }
            }

            if viewModel.isUploadingImage {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var userInfoSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ユーザー名")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)

                TextField("ユーザー名を入力", text: $viewModel.username)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            prefectureRow
        }
    }

    private var prefectureRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("お住まいの地域")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.gray)

            NavigationLink {
                PrefecturePickerView(
                    selectedCode: viewModel.prefectureCode,
                    onSelect: { prefecture in
                        viewModel.prefectureCode = prefecture.code
                    }
                )
            } label: {
                HStack {
                    Text(viewModel.prefectureDisplayName)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

@MainActor
@Observable
final class ProfileEditViewModel {
    var username: String
    var profileImageUrl: String?
    var isUploadingImage = false
    var prefectureCode: String?

    private var profileInfo: ProfileInfo?
    private let prefectureClient: UpdateUserPrefectureClientProtocol
    private var lastSyncedPrefectureCode: String?

    init(
        profileInfo: ProfileInfo?,
        prefectureClient: UpdateUserPrefectureClientProtocol = UpdateUserPrefectureClient()
    ) {
        self.profileInfo = profileInfo
        self.username = profileInfo?.username ?? ""
        self.profileImageUrl = profileInfo?.profileImageUrl
        self.prefectureClient = prefectureClient
        let stored = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue)
        self.prefectureCode = stored
        self.lastSyncedPrefectureCode = stored
    }

    var prefectureDisplayName: String {
        if let code = prefectureCode, let p = Prefecture.find(byCode: code) {
            return p.name
        }
        return "未設定 (\(Prefecture.default.name))"
    }

    func save() {
        guard var profile = profileInfo else {
            persistPrefectureIfChanged()
            return
        }

        // ユーザー名を更新し、表示名もユーザー名と同じにする
        profile.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.displayName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let imageUrl = profileImageUrl {
            profile.profileImageUrl = imageUrl
        }

        // UserDefaultsに保存
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.profileInfo.rawValue)
        } catch {
            print("Failed to save profile: \(error)")
        }

        persistPrefectureIfChanged()
    }

    private func persistPrefectureIfChanged() {
        guard let code = prefectureCode, !code.isEmpty else { return }
        guard code != lastSyncedPrefectureCode else { return }
        UserDefaults.standard.set(code, forKey: UserDefaultsKey.prefectureCode.rawValue)
        lastSyncedPrefectureCode = code

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        guard !uid.isEmpty else { return }
        let client = prefectureClient
        Task {
            _ = try? await client.put(uid: uid, prefectureCode: code)
        }
    }

    func uploadProfileImage(_ image: UIImage) async {
        isUploadingImage = true

        // 画像をローカルに保存
        if let data = image.jpegData(compressionQuality: 0.8) {
            // 固定ファイル名を使用（毎回上書き）
            let filename = "profile_image.jpg"

            // 古いプロフィール画像を削除
            deleteOldProfileImage()

            if let url = saveImageToDocuments(data: data, filename: filename) {
                // ファイル名のみを保存（フルパスではなく）
                profileImageUrl = filename

                // 画像URLをProfileInfoに保存
                guard var profile = profileInfo else { return }
                profile.profileImageUrl = filename

                do {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(profile)
                    UserDefaults.standard.set(data, forKey: UserDefaultsKey.profileInfo.rawValue)
                    profileInfo = profile
                } catch {
                    print("Failed to save profile image: \(error)")
                }
            }
        }

        isUploadingImage = false
    }

    private func saveImageToDocuments(data: Data, filename: String) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    private func deleteOldProfileImage() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        // profile_で始まるファイルをすべて削除
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.lastPathComponent.hasPrefix("profile_") {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            // エラーは無視
        }
    }

    // プロフィール画像の実際のURLを取得するヘルパーメソッド
    func getProfileImageURL() -> URL? {
        guard let filename = profileImageUrl else { return nil }

        // file://で始まる場合は古い形式（フルパス）なので、そのまま返す
        if filename.hasPrefix("file://") {
            return URL(string: filename)
        }

        // ファイル名のみの場合は、ドキュメントディレクトリのパスを構築
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        return documentsDirectory.appendingPathComponent(filename)
    }
}
