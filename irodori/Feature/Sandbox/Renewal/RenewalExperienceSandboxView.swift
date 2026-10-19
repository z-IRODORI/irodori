//
//  RenewalExperienceSandboxView.swift
//  irodori - Sandbox
//
//  リニューアル後アプリの体験 Sandbox (入口)。
//  設計書の矛盾は「最新のドキュメントを優先」で解消している:
//   - ホーム構成: 01 (3要素のみ) を採用し、04/07 の常設データ獲得パネルは撤去
//   - 初回フロー: 04 の「導入 → 4問 → 相棒誕生」を採用。06 の写真 AI 発掘は ＋登録 の1手段として実装
//   - 口調: 03 の5種 (やさしく丁寧 / フレンドリー / クール・簡潔 / ちょっと辛口 / 関西弁)
//   - 文字数: 03 の 45〜65字 を基準に文字数バッジで確認できる
//
//  構成: 初回 → オンボーディング / 2回目以降 → 4タブ (ホーム / カレンダー / ＋登録 / クローゼット)
//  ＋相棒画面 (ホームの相棒アイコンから)。
//  データはすべて端末内のモック。「日付を進める」で毎日の体験 (着眼点ローテーション・被り防止) を確かめられる。
//

import SwiftUI

struct RenewalExperienceSandboxView: View {
    enum TabKey: Hashable { case home, calendar, register, closet }
    enum Route: Hashable { case partner }

    struct RegisterRequest: Identifiable {
        let id = UUID()
        let method: RenewalRegisterMethod?
    }

    @State private var store = RenewalStore()
    @State private var tab: TabKey = .home
    @State private var homePath: [Route] = []
    @State private var registerRequest: RegisterRequest?
    @State private var showToneSheet = false
    @State private var showControls = false
    @State private var confirmReset = false
    /// ホームのデータ接続先 (モック / 実API ローカル / 実API 本番)
    @AppStorage(RenewalHomeDataSource.storageKey) private var homeSourceRaw = RenewalHomeDataSource.local.rawValue
    @State private var liveModel: RenewalLiveHomeModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if store.hasOnboarded {
                tabs
            } else {
                NavigationStack {
                    RenewalOnboardingView(store: store, mode: .first) {}
                        .toolbar { closeToolbar }
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                RenewalToastView(toast: toast, typeName: store.typeName, showCount: store.showCharCount)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { if !toast.isProgress { store.toast = nil } }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: store.toast)
        .task(id: store.toast?.id) {
            guard let toast = store.toast, !toast.isProgress else { return }
            try? await Task.sleep(for: .seconds(4.5))
            if store.toast?.id == toast.id { store.toast = nil }
        }
        .sheet(item: $registerRequest) { request in
            RenewalRegisterSheet(store: store, initialMethod: request.method)
        }
        .sheet(isPresented: $showToneSheet) {
            RenewalToneSheet(store: store)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showControls) {
            controls
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 4タブ

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("ホーム", systemImage: "house", value: TabKey.home) {
                NavigationStack(path: $homePath) {
                    homeContent
                    .toolbar { closeToolbar }
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .partner:
                            RenewalPartnerView(store: store) { method in
                                registerRequest = RegisterRequest(method: method)
                            }
                        }
                    }
                }
            }
            Tab("カレンダー", systemImage: "calendar", value: TabKey.calendar) {
                NavigationStack {
                    RenewalCalendarView(store: store)
                        .toolbar { closeToolbar }
                }
            }
            // 中央の「＋ 登録」はタブとして留まらず、ハーフシートを開く
            Tab("登録", systemImage: "plus.circle", value: TabKey.register) {
                Color.clear
            }
            Tab("クローゼット", systemImage: "hanger", value: TabKey.closet) {
                NavigationStack {
                    RenewalClosetView(
                        store: store,
                        onBuildAround: { item in
                            store.pivot(to: item, scope: .today)
                            homePath = []
                            tab = .home
                        },
                        onOpenRegister: { registerRequest = RegisterRequest(method: nil) }
                    )
                    .toolbar { closeToolbar }
                }
            }
        }
        .tint(RenewalTokens.ink)
        .onChange(of: tab) { old, new in
            if new == .register {
                tab = old
                Haptic.impact(.soft)
                registerRequest = RegisterRequest(method: nil)
            }
        }
    }

    private var homeSource: RenewalHomeDataSource {
        RenewalHomeDataSource(rawValue: homeSourceRaw) ?? .mock
    }

    @ViewBuilder
    private var homeContent: some View {
        if homeSource == .mock {
            RenewalHomeView(
                store: store,
                onOpenPartner: { homePath.append(.partner) },
                onOpenToneSheet: { showToneSheet = true },
                onOpenPhotoPicker: { registerRequest = RegisterRequest(method: .photo) },
                onOpenCalendar: { tab = .calendar }
            )
        } else if let liveModel, liveModel.source == homeSource {
            RenewalLiveHomeView(
                store: store,
                model: liveModel,
                onOpenPartner: { homePath.append(.partner) },
                onOpenToneSheet: { showToneSheet = true },
                onOpenPhotoPicker: { registerRequest = RegisterRequest(method: .photo) },
                onOpenCalendar: { tab = .calendar }
            )
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { liveModel = RenewalLiveHomeModel(source: homeSource) }
        }
    }

    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("閉じる") { dismiss() }
                .foregroundStyle(RenewalTokens.ink)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showControls = true
            } label: {
                Image(systemName: "flask")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Sandbox の操作")
        }
    }

    // MARK: - Sandbox 操作パネル

    private var controls: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("シミュレーション上の今日", value: store.dateLabel(store.state.today))
                    LabeledContent("手持ち", value: "\(store.state.closet.count)着")
                    LabeledContent("着用記録", value: "\(store.state.wears.count)件")
                    LabeledContent("今日の着眼点", value: store.angle(for: store.state.today).label)
                } header: {
                    Text("状態")
                }

                Section {
                    Button("翌朝にする (+1日)") { store.advanceDays(1) }
                    Button("1週間進める (+7日)") { store.advanceDays(7) }
                    Button("2週間進める (+14日・眠っている服の救出日を確認)") { store.advanceDays(14) }
                } header: {
                    Text("時間を進める")
                } footer: {
                    Text("翌朝になると、昨日着た服の被り防止・日替わり着眼点 (A〜E) のローテーション・天気の変化がホームに反映されます。")
                }

                Section {
                    Picker("ホームのデータ", selection: $homeSourceRaw) {
                        ForEach(RenewalHomeDataSource.allCases) { source in
                            Text(source.label).tag(source.rawValue)
                        }
                    }
                } header: {
                    Text("データ接続")
                } footer: {
                    Text("実API はログイン中のアカウントのクローゼット・天気・相棒の話し方で api/home/owned-first から3案を取得し、「今日着る」は実際のカレンダーに保存されます。ローカルは irodori-api を ./run.sh で起動 (port 8080)。カレンダー・クローゼット・相棒タブは引き続きモックです。")
                }

                Section {
                    Toggle("セリフの文字数と着眼点を表示", isOn: Bindable(store).showCharCount)
                } footer: {
                    Text("黄金律 45〜65字 に収まっているかを確認できます (青 = 基準内 / オレンジ = 基準外)。")
                }

                Section {
                    Button("育った状態にする (手持ち7着・着用5回)") {
                        store.applyGrownPreset()
                        showControls = false
                    }
                    Button("最初からやり直す (オンボーディングから)", role: .destructive) {
                        confirmReset = true
                    }
                } header: {
                    Text("シナリオ")
                }

                Section {
                    Button("Sandbox を閉じる") {
                        showControls = false
                        dismiss()
                    }
                } footer: {
                    Text("データはこの Sandbox 専用の保存領域にあり、本番の相棒・クローゼットには影響しません。")
                }
            }
            .navigationTitle("Sandbox の操作")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("最初からやり直しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("やり直す", role: .destructive) {
                    store.reset()
                    homePath = []
                    tab = .home
                    showControls = false
                }
            }
        }
    }
}

#Preview("リニューアル体験 (Mock)") {
    RenewalExperienceSandboxView()
}
