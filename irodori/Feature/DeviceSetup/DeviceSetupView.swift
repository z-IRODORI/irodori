//
//  DeviceSetupView.swift
//  irodori
//
//  玄関カメラ (Raspberry Pi + AI Camera) の設置ガイドと連携画面。
//  未連携: QR をカメラにかざしてペアリング。
//  連携済: 状態 / 設置モード (ライブプレビュー + 全身判定のヒント) / 試し撮り / 設定 / 解除。
//  デザインは白カード + 黒アクセント、成功時だけピンク (スタックチャン実装計画 §2)。
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct DeviceSetupView: View {
    @Binding var path: [ViewType]
    @State private var viewModel: DeviceSetupViewModel
    @State private var showUnlinkConfirm = false
    @State private var showTroubleshooting = false

    @MainActor
    init(path: Binding<[ViewType]>, viewModel: DeviceSetupViewModel? = nil) {
        _path = path
        _viewModel = State(initialValue: viewModel ?? DeviceSetupViewModel())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                switch viewModel.phase {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                case .error(let message):
                    errorCard(message)
                case .unpaired:
                    pairingSection
                case .paired:
                    pairedSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.white)
        .navigationTitle("玄関カメラ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .confirmationDialog("玄関カメラとの連携を解除しますか？", isPresented: $showUnlinkConfirm, titleVisibility: .visible) {
            Button("解除する", role: .destructive) { Task { await viewModel.unlink() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("カメラは撮影を止め、もう一度 QR でつなぎ直すまで記録しません。")
        }
    }

    // MARK: - 未連携: ペアリング

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("玄関に置くだけで、毎朝のコーデを記録")
                .font(.system(size: 22, weight: .bold))
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 8) {
                stepRow(1, "ラズパイの電源を入れて、Wi‑Fi につなぐ")
                stepRow(2, "下の QR をカメラのレンズにかざす (30〜50cm)")
                stepRow(3, "つながったら、立ち位置を決めて試し撮り")
            }

            card {
                VStack(spacing: 14) {
                    if let payload = viewModel.qrPayload, let qr = Self.qrImage(payload) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240, height: 240)
                            .padding(8)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ProgressView().frame(width: 240, height: 240)
                    }
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(viewModel.isClaimExpired ? "コードの期限が切れました" : "カメラが読むのを待っています…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    if viewModel.isClaimExpired {
                        secondaryButton("新しいコードを出す") { Task { await viewModel.beginPairing() } }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            cameraPresenceRow

            if viewModel.lanStreamURL != nil || viewModel.pairingPreviewImage != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("いまカメラが見ているもの")
                        .font(.system(size: 13, weight: .semibold))
                    Group {
                        if let url = viewModel.lanStreamURL {
                            LANStreamView(url: url, onFailure: { viewModel.lanStreamFailed() })
                                .aspectRatio(3 / 4, contentMode: .fit)   // ペアリング前の既定は縦置き
                                .id(url)
                        } else if let img = viewModel.pairingPreviewImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.07), lineWidth: 1))
                    Text("この枠の中に、QR がはっきり大きく写るように iPhone を動かしてください。ぼやけていたら 30〜50cm まで離します。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Text("画面を明るくして、QR 全体がレンズに入るようにゆっくり近づけてください。読み取れると数秒でこの画面が切り替わります。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            troubleshooting

            privacyNote
        }
    }

    /// カメラが起動して QR 待ちになっているか (同じ Wi-Fi からの生存通知で判定)
    private var cameraPresenceRow: some View {
        let (icon, color, text): (String, Color, String) = {
            switch viewModel.cameraPresence {
            case .checking:
                return ("antenna.radiowaves.left.and.right", .secondary, "カメラを探しています…")
            case .notFound:
                return ("exclamationmark.circle", .secondary, "カメラが見つかりません。電源と Wi‑Fi を確認してください")
            case .waiting(let ago):
                return ("checkmark.circle.fill", .green, ago < 10 ? "カメラは起動して QR を待っています" : "カメラは起動しています (\(Int(ago)) 秒前に通信)")
            case .registering:
                return ("arrow.triangle.2.circlepath", .pink, "QR を読み取りました。登録中…")
            case .noWifi:
                return ("wifi.slash", .secondary, "iPhone を自宅の Wi‑Fi につなぐと、カメラの起動を確認できます")
            }
        }()
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: viewModel.cameraPresence)
    }

    private var troubleshooting: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showTroubleshooting.toggle() }
            } label: {
                HStack {
                    Text("読み取れないときは")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                    Image(systemName: showTroubleshooting ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showTroubleshooting {
                VStack(alignment: .leading, spacing: 6) {
                    guideRow("power", "ラズパイの電源が入っていて、緑のランプがゆっくり点滅している (= QR 待ち)")
                    guideRow("wifi", "ラズパイと iPhone が同じ Wi‑Fi につながっている")
                    guideRow("ruler", "画面とレンズの距離は 30〜50cm。QR 全体がレンズに入るように")
                    guideRow("sun.max", "画面の明るさを最大に。反射で読めないときは少し角度を変える")
                    guideRow("clock", "起動直後は 30 秒ほどかかる。緑のランプが点滅し始めてからかざす")
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 連携済

    private var pairedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            statusCard

            if viewModel.device?.setup_mode == true {
                previewCard
            }

            HStack(spacing: 10) {
                primaryButton(viewModel.device?.setup_mode == true ? "設置モードを終了" : "設置モード") {
                    Task { await viewModel.toggleSetupMode() }
                }
                primaryButton(viewModel.isWaitingTestCapture ? "撮影を待っています…" : "試し撮り",
                              disabled: viewModel.isWaitingTestCapture || viewModel.device?.online != true) {
                    Task { await viewModel.requestTestCapture() }
                }
            }

            placementGuide

            if let cap = viewModel.device?.last_capture {
                lastCaptureCard(cap)
            }

            settingsCard

            Button {
                showUnlinkConfirm = true
            } label: {
                Text("連携を解除")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            privacyNote
        }
    }

    private var statusCard: some View {
        card {
            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.device?.online == true ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.stateLabel)
                        .font(.system(size: 15, weight: .bold))
                    Text(lastSeenText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(viewModel.device?.model ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// LAN 配信の枠の比率。縦置き (90/270) は 3:4、横置きは 4:3
    private var streamAspect: CGFloat {
        let r = viewModel.device?.settings.rotation ?? 90
        return (r == 90 || r == 270) ? 3.0 / 4.0 : 4.0 / 3.0
    }

    private var lastSeenText: String {
        guard let t = viewModel.device?.last_seen_at else { return "まだ一度も通信していません" }
        let sec = Int(Date().timeIntervalSince1970 - t)
        if sec < 60 { return "さっき通信したよ" }
        if sec < 3600 { return "\(sec / 60) 分前に通信" }
        return "\(sec / 3600) 時間前に通信"
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("いまカメラが見ているもの")
                .font(.system(size: 14, weight: .semibold))
            ZStack(alignment: .bottom) {
                Group {
                    if let url = viewModel.lanStreamURL {
                        // 同じ Wi-Fi: ラズパイの MJPEG ページを直接表示 (15fps・低遅延)。枠は向き設定に合わせる
                        LANStreamView(url: url, onFailure: { viewModel.lanStreamFailed() })
                            .aspectRatio(streamAspect, contentMode: .fit)
                            .id(url)
                    } else if let img = viewModel.previewImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.08))
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .overlay(
                                VStack(spacing: 6) {
                                    ProgressView()
                                    Text("映像を待っています…").font(.system(size: 12)).foregroundStyle(.secondary)
                                }
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(viewModel.isFullBodyOK ? Color.pink : Color.black.opacity(0.07), lineWidth: viewModel.isFullBodyOK ? 3 : 1)
                )

                hintBand
                    .padding(12)
            }
            Text("立ち位置から 1.8〜2.5m、カメラの高さは 1.0〜1.3m、縦置き。窓を背にしない。ヒントが全部消えてピンクの枠になれば OK。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var hintBand: some View {
        let text: String = {
            if !viewModel.isPersonPresent { return "カメラの前に立ってみて" }
            if viewModel.isFullBodyOK { return "全身ばっちり！" }
            return viewModel.hints.first ?? "全身が写るかチェック！"
        }()
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(viewModel.isFullBodyOK ? .white : .black)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(viewModel.isFullBodyOK ? Color.pink : Color.white.opacity(0.92))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .animation(.easeInOut(duration: 0.2), value: text)
    }

    private var placementGuide: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("置き方のコツ")
                    .font(.system(size: 14, weight: .semibold))
                guideRow("figure.stand", "立ち位置から 1.8〜2.5m 離す。足元まで入る距離")
                guideRow("arrow.up.and.down", "カメラの高さは 1.0〜1.3m。縦置きにする")
                guideRow("sun.max", "窓を背にしない。逆光だと服の色が飛ぶ")
                guideRow("clock", "記録するのは朝の時間帯だけ (下の設定で変えられる)")
                guideRow("bell", "記録できたら、写真つきで通知するよ")
            }
        }
    }

    private func lastCaptureCard(_ cap: DeviceCaptureSummary) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(cap.trigger == "test" ? "試し撮り" : "最近の記録")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(captureStatusLabel(cap))
                        .font(.system(size: 12))
                        .foregroundStyle(cap.status == "completed" ? Color.pink : .secondary)
                }
                if let thumbs = cap.thumbnails, !thumbs.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(thumbs.enumerated()), id: \.offset) { i, url in
                            ZStack(alignment: .topLeading) {
                                // 3 枚を同じ大きさ (3:4) に揃える。scaledToFill は overlay 側に置き、枠は Color.clear で決める
                                Color.clear
                                    .aspectRatio(3 / 4, contentMode: .fit)
                                    .overlay(
                                        CachedAsyncImage(url: url.flatMap(URL.init(string:))) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Rectangle().fill(Color.gray.opacity(0.08))
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(cap.selected_index == i ? Color.pink : Color.black.opacity(0.07),
                                                lineWidth: cap.selected_index == i ? 2 : 1)
                                )
                                if cap.selected_index == i {
                                    Text("この1枚")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.pink)
                                        .clipShape(Capsule())
                                        .padding(6)
                                }
                            }
                        }
                    }
                }
                if let error = cap.error, cap.status != "completed", cap.status != "processing" {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                if cap.status == "completed", let id = cap.coordinate_id {
                    secondaryButton("記録を見る") {
                        path.append(.coordinateDetail(.init(coordinateId: id, coordinateImageURL: cap.thumbnails?.compactMap { $0 }.first ?? "", showHeader: true)))
                    }
                }
            }
        }
    }

    private func captureStatusLabel(_ cap: DeviceCaptureSummary) -> String {
        switch cap.status {
        case "processing": return "解析中…"
        case "completed": return "記録できた"
        case "canceled": return "全身が写らなかった"
        case "failed": return "うまくいかなかった"
        default: return ""
        }
    }

    private var settingsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("設定")
                    .font(.system(size: 14, weight: .semibold))
                HStack {
                    Text("記録する時間帯").font(.system(size: 13))
                    Spacer()
                    hourPicker($viewModel.settingsDraft.window_start_hour)
                    Text("〜").font(.system(size: 13)).foregroundStyle(.secondary)
                    hourPicker($viewModel.settingsDraft.window_end_hour)
                }
                Toggle(isOn: $viewModel.settingsDraft.notify_on_capture) {
                    Text("記録できたら知らせる").font(.system(size: 13))
                }
                .tint(.black)
                HStack {
                    Text("次の撮影まで").font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $viewModel.settingsDraft.capture_cooldown_s) {
                        Text("30秒").tag(30)
                        Text("1分").tag(60)
                        Text("2分").tag(120)
                        Text("5分").tag(300)
                        Text("10分").tag(600)
                    }
                    .pickerStyle(.menu)
                    .tint(.black)
                }
                Toggle(isOn: $viewModel.settingsDraft.one_per_day) {
                    Text("1日1回だけ記録する").font(.system(size: 13))
                }
                .tint(.black)
                HStack {
                    Text("カメラの向き").font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $viewModel.settingsDraft.rotation) {
                        Text("縦置き").tag(90)
                        Text("縦置き (逆)").tag(270)
                        Text("横置き").tag(0)
                        Text("横置き (逆)").tag(180)
                    }
                    .pickerStyle(.menu)
                    .tint(.black)
                }
                if viewModel.settingsDraft != viewModel.device?.settings {
                    secondaryButton("保存") { Task { await viewModel.saveSettings() } }
                }
            }
        }
    }

    private func hourPicker(_ value: Binding<Int>) -> some View {
        Picker("", selection: value) {
            ForEach(0..<25, id: \.self) { h in Text("\(h)時").tag(h) }
        }
        .pickerStyle(.menu)
        .tint(.black)
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("プライバシー")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("記録する時間帯の外ではカメラは止まっています。撮った 3 枚と選ばれた 1 枚はあなただけが見られ、「連携を解除」でいつでも止められます。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 部品

    private func errorCard(_ message: String) -> some View {
        card {
            VStack(spacing: 10) {
                Text(message).font(.system(size: 14))
                secondaryButton("もう一度") { Task { await viewModel.start() } }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.05), lineWidth: 1))
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.black)
                .clipShape(Circle())
            Text(text).font(.system(size: 14))
        }
    }

    private func guideRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 20)
            Text(text).font(.system(size: 13))
        }
    }

    private func primaryButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(disabled ? Color.gray.opacity(0.4) : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 48))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    static func qrImage(_ payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

#Preview("未連携") {
    NavigationStack {
        DeviceSetupView(path: .constant([]), viewModel: DeviceSetupViewModel(client: MockDeviceClient()))
    }
}

#Preview("連携済・設置モード") {
    let mock = MockDeviceClient()
    mock.devices = [MockDeviceClient.sampleDevice(setupMode: true)]
    return NavigationStack {
        DeviceSetupView(path: .constant([]), viewModel: DeviceSetupViewModel(client: mock))
    }
}
