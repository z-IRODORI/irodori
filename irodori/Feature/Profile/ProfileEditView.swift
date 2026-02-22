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
        NavigationStack {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        path.removeLast()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.save()
                        path.removeLast()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
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
    }

    private var profileImageSection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let profileImageUrl = viewModel.profileImageUrl,
                       let url = URL(string: profileImageUrl) {
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
                Text("表示名")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)

                TextField("表示名を入力", text: $viewModel.displayName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("ユーザー名")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)

                Text(viewModel.username)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.gray)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("登録日")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)

                Text(viewModel.formattedCreatedAt)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.gray)
            }
        }
    }
}

@MainActor
@Observable
final class ProfileEditViewModel {
    var username: String
    var displayName: String
    var profileImageUrl: String?
    var createdAt: Date
    var lastLoginAt: Date?
    var isUploadingImage = false

    private var profileInfo: ProfileInfo?

    init(profileInfo: ProfileInfo?) {
        self.profileInfo = profileInfo
        self.username = profileInfo?.username ?? ""
        self.displayName = profileInfo?.displayName ?? ""
        self.profileImageUrl = profileInfo?.profileImageUrl
        self.createdAt = profileInfo?.createdAt ?? Date()
        self.lastLoginAt = profileInfo?.lastLoginAt
    }

    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: createdAt)
    }

    func save() {
        guard var profile = profileInfo else { return }

        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
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
    }

    func uploadProfileImage(_ image: UIImage) async {
        isUploadingImage = true

        // TODO: 実際のAPIを使用して画像をアップロードする
        // 今はダミー実装として、画像をローカルに保存する
        if let data = image.jpegData(compressionQuality: 0.8) {
            let filename = "profile_\(UUID().uuidString).jpg"
            if let url = saveImageToDocuments(data: data, filename: filename) {
                profileImageUrl = url.absoluteString
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
}
