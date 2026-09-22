//
//  DeviceSetupViewModel.swift
//  irodori
//
//  玄関カメラの連携画面の状態。
//  - 未連携: claim を発行して QR を出し、デバイスが登録されるまで一覧をポーリングする
//  - 連携済: 状態を定期取得 (設置モード中は 1 秒・通常 5 秒)、試し撮り・設定・解除
//  試し撮りで作られた解析ジョブは AnalysisJobStore に渡し、既存の常駐トースターで結果まで追う。
//

import UIKit
import FirebaseAuth

@MainActor
@Observable
final class DeviceSetupViewModel {
    enum Phase: Equatable {
        case loading
        case unpaired
        case paired
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var device: DeviceInfo?
    private(set) var qrPayload: String?
    private(set) var claimExpiresAt: Date?
    /// ペアリング画面でのカメラの起動状況 (同じネットワークからの生存通知)
    enum CameraPresence: Equatable {
        case checking          // まだ 1 回も確認できていない
        case notFound          // 通知が来ていない (電源 / Wi-Fi を疑う)
        case waiting(Double)   // QR 待ち (何秒前に通信したか)
        case registering       // QR を読んで登録中
        case noWifi            // iPhone 側のネットワークが判定できない
    }
    private(set) var cameraPresence: CameraPresence = .checking
    /// ペアリング前のカメラ映像 (QR の位置合わせ用)
    private(set) var pairingPreviewImage: UIImage?
    /// LAN 直接配信の URL (同じ Wi-Fi のとき)。失敗したら nil に戻してクラウド経路へ
    private(set) var lanStreamURL: URL?
    private var lanStreamFailedURL: String?
    private(set) var previewImage: UIImage?
    private(set) var isSendingCommand = false
    /// 試し撮りを送ってから結果 (last_capture) が来るまで true
    private(set) var isWaitingTestCapture = false
    var settingsDraft = DeviceSettings(window_start_hour: 6, window_end_hour: 11, one_per_day: false, rotation: 90)
    /// 通知の許可を一度は求めたか (連携済み画面を開いたとき 1 回だけ)
    private var askedNotification = false

    private let client: DeviceClientProtocol
    private var pollTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    private var pairingPreviewTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewSeq = 0
    private var testCaptureSentAt: Double = 0
    private var attachedJobId: String?

    init(client: DeviceClientProtocol = DeviceClient()) {
        self.client = client
    }

    // MARK: - 認証情報

    private func credentials() async -> (userId: String, idToken: String)? {
        guard let userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue), !userId.isEmpty,
              let user = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { return nil }
        return (userId, token)
    }

    // MARK: - ライフサイクル

    func start() async {
        phase = .loading
        await reload()
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        presenceTask?.cancel()
        presenceTask = nil
        pairingPreviewTask?.cancel()
        pairingPreviewTask = nil
        stopPreviewLoop()
    }

    private func reload() async {
        guard let c = await credentials() else {
            phase = .error("ログイン情報が取得できませんでした")
            return
        }
        guard let result = try? await client.listDevices(userId: c.userId, idToken: c.idToken) else {
            phase = .error("通信状況に問題があるかもしれません")
            return
        }
        switch result {
        case .success(let list):
            if let first = list.devices.first {
                applyDevice(first)
                phase = .paired
                startDevicePolling()
                await askNotificationOnce()
            } else {
                phase = .unpaired
                await beginPairing()
            }
        case .failure(let error):
            phase = .error(error.errorDescription)
        }
    }

    // MARK: - ペアリング (未連携)

    func beginPairing() async {
        guard let c = await credentials() else { return }
        guard let result = try? await client.createClaim(userId: c.userId, idToken: c.idToken),
              case .success(let claim) = result else {
            ToastManager.shared.show("ペアリングコードを発行できませんでした")
            return
        }
        qrPayload = claim.qr_payload
        claimExpiresAt = Date().addingTimeInterval(TimeInterval(claim.expires_in))
        startPairingPolling()
        startPresencePolling()
        startPairingPreviewLoop()
    }

    /// ペアリング前のカメラ映像をロングポーリングで受け取り続ける (設置モードと同じ仕組み)
    private func startPairingPreviewLoop() {
        pairingPreviewTask?.cancel()
        pairingPreviewTask = Task { [weak self] in
            var seq = 0
            var failures = 0
            while !Task.isCancelled {
                guard let self, self.phase == .unpaired, let c = await self.credentials() else { return }
                do {
                    if let result = try await self.client.fetchPresencePreview(after: seq, wait: 3.0, userId: c.userId, idToken: c.idToken) {
                        seq = result.seq
                        self.pairingPreviewImage = result.image
                    }
                    failures = 0
                } catch {
                    failures += 1
                    try? await Task.sleep(for: .seconds(min(3.0, 0.5 * Double(failures))))
                }
            }
        }
    }

    /// 同じネットワークで QR 待ちのカメラがいるかを 1.5 秒ごとに確認する
    private func startPresencePolling() {
        presenceTask?.cancel()
        presenceTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.phase == .unpaired else { return }
                if let c = await self.credentials(),
                   let result = try? await self.client.getPresence(userId: c.userId, idToken: c.idToken),
                   case .success(let res) = result {
                    if !res.client_ip_known {
                        self.cameraPresence = .noWifi
                    } else if let d = res.devices.first {
                        self.cameraPresence = (d.state == "registering" || d.state == "reading")
                            ? .registering : .waiting(d.seen_ago_s)
                        self.updateLANStream(d.lan_stream_url)
                    } else {
                        self.cameraPresence = .notFound
                    }
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    var isClaimExpired: Bool {
        guard let claimExpiresAt else { return false }
        return Date() >= claimExpiresAt
    }

    private func startPairingPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.phase == .unpaired else { return }
                guard let c = await self.credentials(),
                      let result = try? await self.client.listDevices(userId: c.userId, idToken: c.idToken),
                      case .success(let list) = result else { continue }
                if let first = list.devices.first {
                    self.presenceTask?.cancel()
                    self.presenceTask = nil
                    self.pairingPreviewTask?.cancel()
                    self.pairingPreviewTask = nil
                    self.pairingPreviewImage = nil
                    self.applyDevice(first)
                    self.phase = .paired
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    ToastManager.shared.show("玄関カメラとつながりました", style: .normal)
                    self.startDevicePolling()
                    await self.askNotificationOnce()
                    return
                }
            }
        }
    }

    /// 記録完了のプッシュ通知の許可を求める (連携済みの文脈で 1 回だけ)。許可済みならトークン登録のみ
    private func askNotificationOnce() async {
        guard !askedNotification else { return }
        askedNotification = true
        await PushNotificationManager.shared.requestAuthorizationAndRegister()
    }

    // MARK: - 連携済

    /// LAN 配信 URL の更新。一度失敗した URL は再挑戦しない (クラウド経路に固定)
    private func updateLANStream(_ urlString: String?) {
        guard let urlString, urlString != lanStreamFailedURL, let url = URL(string: urlString) else {
            if urlString == nil { lanStreamURL = nil }
            return
        }
        if lanStreamURL != url { lanStreamURL = url }
    }

    func lanStreamFailed() {
        lanStreamFailedURL = lanStreamURL?.absoluteString
        lanStreamURL = nil
    }

    private func applyDevice(_ d: DeviceInfo) {
        let settingsChanged = device?.settings != d.settings
        device = d
        if d.setup_mode { updateLANStream(d.lan_stream_url) } else { lanStreamURL = nil }
        // 設置モードの間だけライブプレビューのロングポーリングを回す
        if d.setup_mode {
            startPreviewLoopIfNeeded()
        } else {
            stopPreviewLoop()
        }
        if settingsChanged || device == nil {
            settingsDraft = d.settings
        }
        // 試し撮りの結果 (job_id) が来たら常駐トースターに渡す
        if isWaitingTestCapture,
           let cap = d.last_capture,
           (cap.captured_at ?? 0) >= testCaptureSentAt - 5,
           let jobId = cap.job_id, attachedJobId != jobId {
            attachedJobId = jobId
            isWaitingTestCapture = false
            let thumb = cap.thumbnails?.compactMap { $0 }.first.flatMap(URL.init(string:))
            AnalysisJobStore.shared.attach(jobId: jobId, thumbnailURL: thumb)
        }
    }

    private func startDevicePolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval: Double = (self?.device?.setup_mode ?? false) ? 1.0 : 5.0
                try? await Task.sleep(for: .seconds(interval))
                guard let self, self.phase == .paired, let id = self.device?.device_id else { return }
                await self.refreshDevice(id: id)
            }
        }
    }

    private func refreshDevice(id: String) async {
        guard let c = await credentials(),
              let result = try? await client.getDevice(deviceId: id, userId: c.userId, idToken: c.idToken) else { return }
        switch result {
        case .success(let d):
            applyDevice(d)
        case .failure(let e):
            if case .notFound = e {
                // 別端末で解除された
                device = nil
                phase = .unpaired
                await beginPairing()
            }
        }
    }

    // MARK: - ライブプレビュー (ロングポーリング)

    /// サーバに「手元の seq より新しいフレームが来たら即返して」と頼み続ける。
    /// 返ってきたら間を置かずに次を要求するので、遅延はネット往復 1 回分に収まる。
    private func startPreviewLoopIfNeeded() {
        guard previewTask == nil, let id = device?.device_id else { return }
        previewSeq = 0
        previewTask = Task { [weak self] in
            var failures = 0
            while !Task.isCancelled {
                guard let self, let c = await self.credentials() else { return }
                do {
                    if let result = try await self.client.fetchPreview(
                        deviceId: id, after: self.previewSeq, wait: 3.0, userId: c.userId, idToken: c.idToken
                    ) {
                        self.previewSeq = result.seq
                        self.previewImage = result.image
                    }
                    failures = 0
                } catch {
                    failures += 1
                    try? await Task.sleep(for: .seconds(min(3.0, 0.5 * Double(failures))))
                }
            }
        }
    }

    private func stopPreviewLoop() {
        previewTask?.cancel()
        previewTask = nil
        previewImage = nil
    }

    // MARK: - 操作

    func toggleSetupMode() async {
        guard let d = device else { return }
        await send(d.setup_mode ? .setupOff : .setupOn)
        if let id = device?.device_id { await refreshDevice(id: id) }
    }

    func requestTestCapture() async {
        guard device != nil else { return }
        testCaptureSentAt = Date().timeIntervalSince1970
        isWaitingTestCapture = true
        await send(.testCapture)
        ToastManager.shared.show("カメラの前に立ってください。3秒後に撮ります", style: .normal)
    }

    private func send(_ command: DeviceCommand) async {
        guard let d = device, let c = await credentials() else { return }
        isSendingCommand = true
        defer { isSendingCommand = false }
        guard let result = try? await client.sendCommand(deviceId: d.device_id, command: command, userId: c.userId, idToken: c.idToken),
              case .success = result else {
            ToastManager.shared.show("カメラに送れませんでした")
            isWaitingTestCapture = false
            return
        }
    }

    func saveSettings() async {
        guard let d = device, let c = await credentials() else { return }
        guard let result = try? await client.updateSettings(deviceId: d.device_id, settings: settingsDraft, userId: c.userId, idToken: c.idToken),
              case .success(let updated) = result else {
            ToastManager.shared.show("設定を保存できませんでした")
            return
        }
        applyDevice(updated)
        ToastManager.shared.show("設定を保存しました", style: .normal)
    }

    func unlink() async {
        guard let d = device, let c = await credentials() else { return }
        guard let result = try? await client.unlink(deviceId: d.device_id, userId: c.userId, idToken: c.idToken),
              case .success = result else {
            ToastManager.shared.show("解除できませんでした")
            return
        }
        device = nil
        previewImage = nil
        phase = .unpaired
        ToastManager.shared.show("連携を解除しました", style: .normal)
        await beginPairing()
    }

    // MARK: - 表示用

    var stateLabel: String {
        guard let d = device else { return "" }
        if !d.online { return "オフライン" }
        switch d.status?.state {
        case "pairing": return "ペアリング待ち"
        case "sleep": return "おやすみ中 (記録時間外)"
        case "idle": return "見ているよ"
        case "framing": return "人を見つけた"
        case "ready", "countdown": return "撮るよ！"
        case "burst": return "撮影中"
        case "upload", "waiting": return "送信中"
        case "done": return "記録したよ"
        case "cooldown": return "今日は記録済み"
        default: return "オンライン"
        }
    }

    var hints: [String] {
        device?.status?.judgement?.hints ?? []
    }

    var isFullBodyOK: Bool {
        (device?.status?.judgement?.ok ?? false)
    }

    var isPersonPresent: Bool {
        device?.status?.judgement?.present ?? false
    }
}
