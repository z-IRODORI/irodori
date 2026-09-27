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
    @State private var showQRFullScreen = false

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
                stepRow(2, "下の QR をタップして全画面にし、レンズに向ける (80cm〜1m)")
                stepRow(3, "つながったら、立ち位置を決めて試し撮り")
            }

            card {
                VStack(spacing: 14) {
                    if let payload = viewModel.qrPayload, let qr = Self.qrImage(payload) {
                        Button {
                            Haptic.impact(.soft)
                            showQRFullScreen = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(uiImage: qr)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Text("タップで全画面 (遠くからも読めるように)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .fullScreenCover(isPresented: $showQRFullScreen) {
                            QRFullScreenView(image: qr)
                        }
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
                    Text("この枠の中に QR がはっきり写るように iPhone を動かしてください。近すぎるとぼやけるので、80cm〜1m 離します。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Text("QR をタップして全画面にし、下の映像で QR がはっきり写る位置 (80cm〜1m) で止めてください。読み取れると数秒でこの画面が切り替わります。")
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
                    guideRow("ruler", "QR を全画面にして 80cm〜1m。近すぎるとピントが合わない")
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

            attireRuleCard

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
        let settings = viewModel.device?.settings
        let r = (settings?.rotation_auto ?? true)
            ? (viewModel.device?.status?.judgement?.effective_rotation ?? settings?.rotation ?? 90)
            : (settings?.rotation ?? 90)
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
                    // 枠の色で達成度を見せる: 無色 (人なし) → 黄 → 緑 (撮影できる)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(readinessColor, lineWidth: viewModel.isFullBodyOK ? 5 : 3)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.readiness)
                )

                hintBand
                    .padding(12)
            }
            Text("映像の緑の点と線は、カメラが見つけた体の部位です。枠が黄色から緑になれば撮影できる状態です。立ち位置から 1.8〜2.5m、カメラの高さは 1.0〜1.3m が目安。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    /// 達成度 → 枠色。0 = 無色、途中 = 黄〜黄緑、1 = 緑。服装チェックに引っかかればオレンジ
    private var readinessColor: Color {
        let r = viewModel.readiness
        if r > 0 && viewModel.isAttireBlocked { return Color.orange }
        if r <= 0 { return Color.black.opacity(0.07) }
        if r >= 1 { return Color.green }
        // 黄 (hue 0.14) → 緑 (hue 0.33) へ滑らかに
        return Color(hue: 0.14 + 0.19 * r, saturation: 0.85, brightness: 0.9)
    }

    @ViewBuilder
    private var hintBand: some View {
        let blocked = viewModel.isPersonPresent && viewModel.isAttireBlocked
        let text: String = {
            if !viewModel.isPersonPresent { return "カメラの前に立ってみて" }
            if blocked {
                if let labels = viewModel.attire?.exposed_labels, !labels.isEmpty {
                    return "この服装は送りません（\(labels.joined(separator: "・"))）"
                }
                return "服装を判定できません（暗さ・逆光）"
            }
            if viewModel.isFullBodyOK { return "撮影できるよ！" }
            return viewModel.hints.first ?? "全身が写るかチェック！"
        }()
        HStack(spacing: 8) {
            if viewModel.isPersonPresent && !viewModel.isFullBodyOK && !blocked {
                Text("\(Int(viewModel.readiness * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle((viewModel.isFullBodyOK && !blocked) || blocked ? .white : .black)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(blocked ? Color.orange : (viewModel.isFullBodyOK ? Color.green : Color.white.opacity(0.92)))
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

    /// 送らない服装のルール (プライバシー)。撮る前に知ってもらう
    private var attireRuleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("送らない服装")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("次の 3 か所が服で隠れていない写真は、カメラの中で消去してサーバーに送りません。")
                    .font(.system(size: 13))
                HStack(spacing: 8) {
                    ForEach(["胸", "おなか", "太ももの付け根"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text("裸・下着・水着・スポーツブラ・おへそが見える服などが当てはまります。ノースリーブや膝丈のショートパンツは送ります。設置モードの映像で、この服装が送れるかを事前に確認できます。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("肌に近い色の服や、暗い・逆光の場所では誤って止めることがあります。その場合は理由を通知でお知らせするので、試し撮りでやり直せます。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(cap.status == "completed" ? Color.pink : (cap.status == "skipped" ? Color.orange : .secondary))
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
                if cap.status == "skipped" {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text(cap.skip?.reason ?? "服装を判定できなかったため")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("写真はカメラの中で消去し、サーバーには送っていません。上の「送らない服装」のルールに当てはまったためです。着替えたら試し撮りでやり直せます。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else if let error = cap.error, cap.status != "completed", cap.status != "processing" {
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
        case "skipped": return "送りませんでした"
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
                HStack {
                    Text("服装チェック").font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $viewModel.settingsDraft.attire_check) {
                        Text("厳しめ (推奨)").tag("strict")
                        Text("ふつう").tag("normal")
                        Text("オフ").tag("off")
                    }
                    .pickerStyle(.menu)
                    .tint(.black)
                }
                Text(attireLevelDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Toggle(isOn: $viewModel.settingsDraft.notify_on_shot) {
                    Text("撮影したら知らせる").font(.system(size: 13))
                }
                .tint(.black)
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
                    Text("映像の向き").font(.system(size: 13))
                    Spacer()
                    Picker("", selection: rotationSelection) {
                        Text("自動 (推奨)").tag(-1)
                        Text("そのまま").tag(0)
                        Text("90° 回す").tag(90)
                        Text("180° 回す").tag(180)
                        Text("270° 回す").tag(270)
                    }
                    .pickerStyle(.menu)
                    .tint(.black)
                }
                Text(rotationDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if viewModel.settingsDraft != viewModel.device?.settings {
                    secondaryButton("保存") { Task { await viewModel.saveSettings() } }
                }
            }
        }
    }

    /// 「自動」は -1、手動は角度。自動を選ぶと rotation_auto=true、角度を選ぶと false + その角度
    private var rotationSelection: Binding<Int> {
        Binding(
            get: { viewModel.settingsDraft.rotation_auto ? -1 : viewModel.settingsDraft.rotation },
            set: { v in
                if v < 0 {
                    viewModel.settingsDraft.rotation_auto = true
                } else {
                    viewModel.settingsDraft.rotation_auto = false
                    viewModel.settingsDraft.rotation = v
                }
            }
        )
    }

    private var rotationDescription: String {
        if viewModel.settingsDraft.rotation_auto {
            if let r = viewModel.device?.status?.judgement?.effective_rotation {
                return "人が写ったとき頭が上になる向きを自動で選びます (いまは \(r)°)"
            }
            return "人が写ったとき頭が上になる向きを自動で選びます"
        }
        return "映像が横倒しや逆さまなら、正立するまで回してください"
    }

    private var attireLevelDescription: String {
        switch viewModel.settingsDraft.attire_check {
        case "normal": return "下着・裸・水着だけ止めます。おへそが少し見える程度は送ります"
        case "off": return "服装で止めません。すべての写真を送ります"
        default: return "胸・おなか・太ももの付け根が隠れていなければ送りません。判定できないときも送りません"
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
