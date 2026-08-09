import SwiftUI
import PhotosUI
import FirebaseAuth

struct ProfileEditView: View {
    @Binding var path: [ViewType]
    @State private var viewModel: ProfileEditViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountFinalConfirmation = false

    init(path: Binding<[ViewType]>, profileInfo: ProfileInfo?) {
        self._path = path
        self._viewModel = State(initialValue: ProfileEditViewModel(profileInfo: profileInfo))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileImageSection
                userInfoSection
                logoutSection
                deleteAccountSection
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
        .alert("ログアウトしますか？", isPresented: $showLogoutConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("ログアウト", role: .destructive) {
                do {
                    try AuthManager.shared.signOut()
                    AnalyticsLogger.shared.log(action: .logout)
                } catch {
                    ToastManager.shared.show("ログアウトに失敗しました。もう一度お試しください。")
                }
            }
        } message: {
            Text("登録したデータは端末に残ります。同じ電話番号で再ログインすると引き続き利用できます。")
        }
        .alert("アカウントを削除しますか？", isPresented: $showDeleteAccountConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                showDeleteAccountFinalConfirmation = true
            }
        } message: {
            Text("コーデ・クローゼット・プロフィールなど、すべてのデータが完全に削除されます。この操作は取り消せません。")
        }
        .alert("本当に削除しますか？", isPresented: $showDeleteAccountFinalConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("完全に削除する", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
        } message: {
            Text("同じ電話番号で登録し直すことはできますが、削除したデータは復元できません。")
        }
        .overlay {
            if viewModel.isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("アカウントを削除しています…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
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

            locationsSection
        }
    }

    private var logoutSection: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            Text("ログアウト")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
    }

    private var deleteAccountSection: some View {
        Button {
            showDeleteAccountConfirmation = true
        } label: {
            Text("アカウントを削除")
                .font(.system(size: 13))
                .foregroundStyle(.red.opacity(0.8))
                .underline()
        }
        .buttonStyle(.plain)
        .padding(.bottom, 24)
    }

    // MARK: - 場所 (複数登録)

    /// メイン行 (先頭固定・削除不可) + 追加行 + 「場所を追加」行を1セクションに縦積み.
    /// 連絡先編集の複数値フィールドと同じパターン。メインのみ天気コーデ提案に使われる.
    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("場所")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.gray)

            mainLocationRow

            ForEach(viewModel.additionalPrefectureCodes, id: \.self) { code in
                additionalLocationRow(code: code)
            }

            addLocationRow

            Text(locationsFooterText)
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .padding(.horizontal, 4)
        }
    }

    private var locationsFooterText: String {
        var text = "コーデ提案の天気にはメインの場所が使われます。メインは1日1回まで変更できます。"
        if !viewModel.canAddLocation {
            text += "\n登録できる場所は最大\(ProfileEditViewModel.maxLocationCount)件です。"
        }
        return text
    }

    private var mainLocationRow: some View {
        Group {
            if viewModel.canChangePrefectureToday {
                NavigationLink {
                    PrefecturePickerView(
                        selectedCode: viewModel.prefectureCode,
                        registeredCodes: viewModel.allLocationCodes,
                        onSelect: { prefecture in
                            viewModel.prefectureCode = prefecture.code
                        }
                    )
                } label: { mainLocationRowLabel }
                .buttonStyle(.plain)
            } else {
                Button {
                    ToastManager.shared.show("メインの場所は1日1回まで変更できます")
                } label: { mainLocationRowLabel }
                .buttonStyle(.plain)
            }
        }
    }

    private var mainLocationRowLabel: some View {
        HStack(spacing: 8) {
            Text(viewModel.prefectureDisplayName)
                .foregroundStyle(.primary)
            Text("メイン")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            Spacer()
            Image(systemName: viewModel.canChangePrefectureToday ? "chevron.right" : "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("メインの場所、\(viewModel.prefectureDisplayName)")
        .accessibilityHint(viewModel.canChangePrefectureToday ? "ダブルタップで変更できます" : "本日は変更できません")
    }

    private func additionalLocationRow(code: String) -> some View {
        let name = Prefecture.find(byCode: code)?.name ?? ""
        return HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.removeLocation(code: code)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name)を削除")

            NavigationLink {
                PrefecturePickerView(
                    selectedCode: code,
                    registeredCodes: viewModel.allLocationCodes,
                    title: "場所を変更",
                    onSelect: { prefecture in
                        viewModel.changeLocation(from: code, to: prefecture.code)
                    }
                )
            } label: {
                HStack {
                    Text(name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button {
                viewModel.promoteToMain(code: code)
            } label: {
                Label("メインにする", systemImage: "star")
            }
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.removeLocation(code: code)
                }
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private var addLocationRow: some View {
        NavigationLink {
            PrefecturePickerView(
                selectedCode: nil,
                registeredCodes: viewModel.allLocationCodes,
                title: "場所を追加",
                onSelect: { prefecture in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.addLocation(code: prefecture.code)
                    }
                }
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                Text("場所を追加")
                    .foregroundStyle(.orange)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canAddLocation)
        .opacity(viewModel.canAddLocation ? 1 : 0.4)
    }
}

@MainActor
@Observable
final class ProfileEditViewModel {
    /// メイン含む登録可能な場所の合計上限
    static let maxLocationCount = 5

    var username: String
    var profileImageUrl: String?
    var isUploadingImage = false
    var isDeletingAccount = false
    var prefectureCode: String?
    /// メイン以外の追加場所 (端末ローカルのみ。サーバはメイン1値しか持たない)
    var additionalPrefectureCodes: [String]

    private var profileInfo: ProfileInfo?
    private let prefectureClient: UpdateUserPrefectureClientProtocol
    private let deleteUserClient: DeleteUserClientProtocol
    private var lastSyncedPrefectureCode: String?

    init(
        profileInfo: ProfileInfo?,
        prefectureClient: UpdateUserPrefectureClientProtocol = UpdateUserPrefectureClient(),
        deleteUserClient: DeleteUserClientProtocol = DeleteUserClient()
    ) {
        self.profileInfo = profileInfo
        self.username = profileInfo?.username ?? ""
        self.profileImageUrl = profileInfo?.profileImageUrl
        self.prefectureClient = prefectureClient
        self.deleteUserClient = deleteUserClient
        let stored = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue)
        self.prefectureCode = stored
        self.lastSyncedPrefectureCode = stored
        self.additionalPrefectureCodes = UserDefaults.standard.stringArray(
            forKey: UserDefaultsKey.additionalPrefectureCodes.rawValue
        ) ?? []
    }

    var prefectureDisplayName: String {
        if let code = prefectureCode, let p = Prefecture.find(byCode: code) {
            return p.name
        }
        return "未設定 (\(Prefecture.default.name))"
    }

    // MARK: - 複数場所の管理

    /// メイン + 追加のすべての登録済みコード (ピッカーの重複防止用)
    var allLocationCodes: Set<String> {
        var codes = Set(additionalPrefectureCodes)
        if let main = prefectureCode { codes.insert(main) }
        return codes
    }

    /// メイン枠は未設定でも1枠として数える
    var canAddLocation: Bool {
        additionalPrefectureCodes.count < Self.maxLocationCount - 1
    }

    func addLocation(code: String) {
        guard !allLocationCodes.contains(code) else {
            ToastManager.shared.show("すでに登録されている場所です")
            return
        }
        // メイン未設定なら最初の1件をメインにする (追加のみの状態を作らない)
        guard prefectureCode != nil else {
            prefectureCode = code
            return
        }
        guard canAddLocation else { return }
        additionalPrefectureCodes.append(code)
    }

    func removeLocation(code: String) {
        additionalPrefectureCodes.removeAll { $0 == code }
    }

    func changeLocation(from oldCode: String, to newCode: String) {
        guard oldCode != newCode else { return }
        guard !allLocationCodes.contains(newCode) else {
            ToastManager.shared.show("すでに登録されている場所です")
            return
        }
        if let index = additionalPrefectureCodes.firstIndex(of: oldCode) {
            additionalPrefectureCodes[index] = newCode
        }
    }

    /// 追加の場所をメインへ昇格。メイン変更なので1日1回制限に従う.
    func promoteToMain(code: String) {
        guard canChangePrefectureToday else {
            ToastManager.shared.show("メインの場所は1日1回まで変更できます")
            return
        }
        guard let index = additionalPrefectureCodes.firstIndex(of: code) else { return }
        if let oldMain = prefectureCode {
            // 位置を保ったまま旧メインと入れ替え
            additionalPrefectureCodes[index] = oldMain
        } else {
            additionalPrefectureCodes.remove(at: index)
        }
        prefectureCode = code
    }

    /// 居住地は JST カレンダー日で 1日1回まで変更可能 (コーデ無限再生成防止).
    var canChangePrefectureToday: Bool {
        guard let last = UserDefaults.standard.object(
            forKey: UserDefaultsKey.prefectureLastChangedAt.rawValue
        ) as? Date else { return true }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return !cal.isDate(last, inSameDayAs: Date())
    }

    func save() {
        defer {
            persistPrefectureIfChanged()
            persistAdditionalPrefectures()
        }

        guard var profile = profileInfo else { return }

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
    }

    private func persistPrefectureIfChanged() {
        guard let code = prefectureCode, !code.isEmpty else { return }
        guard code != lastSyncedPrefectureCode else { return }
        guard canChangePrefectureToday else {
            // 1日1回制限。選択は破棄して直近 sync 済みに戻す.
            ToastManager.shared.show("メインの場所は1日1回まで変更できます")
            prefectureCode = lastSyncedPrefectureCode
            return
        }
        UserDefaults.standard.set(code, forKey: UserDefaultsKey.prefectureCode.rawValue)
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKey.prefectureLastChangedAt.rawValue)
        lastSyncedPrefectureCode = code

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        guard !uid.isEmpty else { return }
        let client = prefectureClient
        Task {
            _ = try? await client.put(uid: uid, prefectureCode: code)
        }
    }

    /// 追加場所を保存する。メイン変更が巻き戻された場合に備え、メインとの重複を除いて正規化する.
    private func persistAdditionalPrefectures() {
        let normalized = additionalPrefectureCodes.filter { $0 != prefectureCode }
        additionalPrefectureCodes = normalized
        UserDefaults.standard.set(
            normalized,
            forKey: UserDefaultsKey.additionalPrefectureCodes.rawValue
        )
    }

    // MARK: - 退会

    /// アカウントを完全に削除する。サーバ側で Firestore の全データと Firebase Auth ユーザーを削除し、
    /// 成功したら端末のローカル状態も初期化する。isAuthenticated が false になり SplashView がログイン画面へ戻す。
    func deleteAccount() async {
        guard !isDeletingAccount else { return }
        guard let user = Auth.auth().currentUser else {
            ToastManager.shared.show("ログイン状態を確認できませんでした。再度ログインしてください。")
            return
        }
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            // トークンとローカル userId (旧世代は Firebase UID と異なる) を削除前に確保する
            let idToken = try await user.getIDToken()
            let userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? user.uid
            let result = try await deleteUserClient.delete(userId: userId, idToken: idToken)
            switch result {
            case .success:
                AnalyticsLogger.shared.log(action: .accountDeleted)
                // Auth ユーザーはサーバ側で削除済み。残ったローカルセッションを破棄する
                try? Auth.auth().signOut()
                AccountLocalState.resetForNewRegistration()
            case .failure:
                ToastManager.shared.show("削除に失敗しました。通信環境をご確認のうえ、もう一度お試しください。")
            }
        } catch {
            // サーバ側の削除完了後にレスポンスを受け取れなかった場合、再試行時の getIDToken が
            // user-not-found 等で失敗する。その場合は削除済みとして端末を初期化する
            let nsError = error as NSError
            if let code = AuthErrorCode(rawValue: nsError.code),
               [.userNotFound, .userTokenExpired, .invalidUserToken].contains(code) {
                AnalyticsLogger.shared.log(action: .accountDeleted)
                try? Auth.auth().signOut()
                AccountLocalState.resetForNewRegistration()
                return
            }
            ToastManager.shared.show("削除に失敗しました。通信環境をご確認のうえ、もう一度お試しください。")
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
