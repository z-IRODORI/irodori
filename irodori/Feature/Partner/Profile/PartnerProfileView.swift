//
//  PartnerProfileView.swift
//  irodori
//
//  相棒画面 (案E「シンプル + 週報」)。
//  ・理解度の輪と段階の点 (理解度はミッションの点数の合計。api/partner/profile)
//  ・今週のふりかえり (細い帯 → ストーリー)
//  ・次のミッション (タップでその場所へ)
//  ・あなたのこと: 相棒の発見のタイル。タップで「なんで？」と返事 (api/partner/discoveries/answer)
//

import SwiftUI

@Observable
@MainActor
final class PartnerProfileViewModel {
    var profile: PartnerProfileResponse?
    var isLoading = false
    var loadFailed = false
    /// クリアしたミッション (お祝いのトースト)
    var cleared: PartnerProfileMission?

    private let client: PartnerProfileClientProtocol

    init(client: PartnerProfileClientProtocol = PartnerProfileClient()) {
        self.client = client
    }

    func load() async {
        if profile == nil { isLoading = true }
        defer { isLoading = false }
        let uid = PartnerPatternUtility.userId
        guard !uid.isEmpty, let result = try? await client.get(uid: uid) else {
            loadFailed = profile == nil
            return
        }
        switch result {
        case .success(let p):
            profile = p
            loadFailed = false
        case .failure:
            loadFailed = profile == nil
        }
    }

    func answer(_ discovery: PartnerProfileDiscovery, _ text: String) async {
        guard var p = profile, let i = p.discoveries.firstIndex(where: { $0.id == discovery.id }) else { return }
        // 先に自分の答えを出しておき、相棒の返しは届いてから
        p.discoveries[i].dig?.answer = text
        p.discoveries[i].status = "answered"
        withAnimation(.spring(duration: 0.4)) { profile = p }
        let uid = PartnerPatternUtility.userId
        guard let result = try? await client.answer(uid: uid, discoveryId: discovery.id, answer: text),
              case .success(let res) = result, var latest = profile,
              let j = latest.discoveries.firstIndex(where: { $0.id == discovery.id }) else {
            // 送れなかったら元に戻す
            if var back = profile, let j = back.discoveries.firstIndex(where: { $0.id == discovery.id }) {
                back.discoveries[j].dig?.answer = nil
                back.discoveries[j].status = "new"
                withAnimation { profile = back }
            }
            return
        }
        let before = Set(latest.missions.filter(\.done).map(\.id))
        latest.discoveries[j].dig?.reply = res.reply
        latest = PartnerProfileResponse(status: latest.status, understanding: res.understanding,
                                        missions: res.missions, discoveries: latest.discoveries, weekly: latest.weekly,
                                        color_combos: latest.color_combos)
        withAnimation(.spring(duration: 0.45)) { profile = latest }
        if let newly = res.missions.first(where: { $0.done && !before.contains($0.id) }) {
            Haptic.notify(.success)
            withAnimation(.spring(duration: 0.35)) { cleared = newly }
        }
    }
}

struct PartnerProfileView: View {
    /// 「相棒に相談」(チャットへの遷移は呼び出し元)。nil なら出さない
    var onConsultTap: (() -> Void)? = nil
    /// ミッションの行き先 (open_home など)。check_discoveries はこの画面の中で処理する
    var onMissionAction: ((String) -> Void)? = nil

    @State private var viewModel = PartnerProfileViewModel()
    @State private var showAllMissions = false
    @State private var openDiscoveryId: String?
    @State private var playing = false
    @State private var gauge: CGFloat = 0

    private var profile: PartnerProfileResponse? { viewModel.profile }
    private var found: [PartnerProfileDiscovery] { profile?.discoveries.filter { !$0.isLocked } ?? [] }
    private var locked: [PartnerProfileDiscovery] { profile?.discoveries.filter(\.isLocked) ?? [] }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let p = profile {
                    VStack(spacing: 24) {
                        header(p.understanding)
                        if let weekly = p.weekly, !found.isEmpty { weeklyStrip(weekly) }
                        if let combos = p.color_combos, !combos.isEmpty { colorCombos(combos) }
                        missions(p) { action in
                            if action == "check_discoveries" {
                                withAnimation { proxy.scrollTo("you", anchor: .top) }
                            } else {
                                onMissionAction?(action)
                            }
                        }
                        youSection.id("you")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 80)
                } else if viewModel.loadFailed {
                    failed
                } else {
                    loading
                }
            }
        }
        .background(RenewalTokens.ground)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .onChange(of: profile?.understanding.pct) { _, v in
            withAnimation(.easeOut(duration: 0.9)) { gauge = CGFloat(v ?? 0) / 100 }
        }
        .overlay(alignment: .top) {
            if let m = viewModel.cleared {
                clearedToast(m)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: m.id) {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { viewModel.cleared = nil }
                    }
            }
        }
        .sheet(item: Binding(
            get: { openDiscoveryId.flatMap { id in profile?.discoveries.first(where: { $0.id == id }) } },
            set: { openDiscoveryId = $0?.id }
        )) { d in
            PartnerProfileDiscoverySheet(discovery: d) { text in
                Task { await viewModel.answer(d, text) }
            }
            .presentationDetents([.fraction(0.66), .large])
        }
        .sheet(isPresented: $showAllMissions) {
            if let p = profile {
                PartnerProfileMissionsSheet(understanding: p.understanding, missions: p.missions) { m in
                    onMissionAction?(m.action)
                }
                .presentationDetents([.large])
            }
        }
        .fullScreenCover(isPresented: $playing) {
            if let p = profile, let weekly = p.weekly {
                let picked = weekly.discovery_ids.compactMap { id in p.discoveries.first(where: { $0.id == id }) }
                PartnerProfileStoryPlayer(weekly: weekly, discoveries: picked) { d, text in
                    Task { await viewModel.answer(d, text) }
                }
            }
        }
    }

    // MARK: - 理解度

    private func header(_ u: PartnerUnderstanding) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(RenewalTokens.rule, lineWidth: 7)
                Circle().trim(from: 0, to: gauge)
                    .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                PartnerIconImage(size: 92)
            }
            .frame(width: 124, height: 124)
            .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.1)) { gauge = CGFloat(u.pct) / 100 } }

            VStack(spacing: 4) {
                Text("\(u.pct)%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("相棒の理解度")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(u.stages, id: \.index) { s in
                        Capsule()
                            .fill(u.pct >= s.at_pct ? RenewalTokens.ink : RenewalTokens.border)
                            .frame(width: u.stage.index == s.index ? 22 : 8, height: 8)
                    }
                }
                HStack(spacing: 6) {
                    Text(u.stage.name)
                        .font(.system(size: 13, weight: .semibold))
                    if let next = u.next_stage {
                        Text("あと\(next.at_pct - u.pct)%で\(next.name)")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            if let onConsultTap {
                Button {
                    Haptic.impact(.soft)
                    onConsultTap()
                } label: {
                    Label("相棒に相談する", systemImage: "bubble.left.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(RenewalTokens.surface))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.4), value: u.pct)
    }

    // MARK: - 今週のふりかえり

    private func weeklyStrip(_ weekly: PartnerWeekly) -> some View {
        Button {
            Haptic.impact(.medium)
            playing = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.22))
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今週のあなた")
                        .font(.system(size: 15, weight: .bold))
                    Text("\(weekly.count)つ見つけたよ ・ \(weekly.range)")
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
                HStack(spacing: -5) {
                    ForEach(found.prefix(4)) { d in
                        Circle().fill(PartnerHue(name: d.hue).wash)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .frame(width: 18, height: 18)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [PartnerHue.pink.ink, PartnerHue.lilac.ink, PartnerHue.sky.ink],
                                         startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: PartnerHue.lilac.ink.opacity(0.25), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("今週のふりかえりを見る。\(weekly.count)つの発見")
    }

    // MARK: - あなたに似合う色の組み合わせ

    private func colorCombos(_ combos: [PartnerColorCombo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("あなたに似合う色の組み合わせ")
                    .font(.system(size: 16, weight: .bold))
                Text("手持ちの服から、相棒が選んだ配色")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(combos) { combo in
                        PartnerColorComboCard(combo: combo) { itemId in
                            onMissionAction?("pivot:\(itemId)")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .padding(.horizontal, -20)   // 画面の端までスクロールさせる
        }
    }

    // MARK: - 次のミッション

    private func missions(_ p: PartnerProfileResponse, onAction: @escaping (String) -> Void) -> some View {
        let list = Array(p.missions.filter { !$0.done }.prefix(3))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("次のミッション")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    Haptic.impact(.soft)
                    showAllMissions = true
                } label: {
                    HStack(spacing: 3) {
                        Text("実績 \(p.understanding.cleared)/\(p.understanding.total)")
                            .monospacedDigit()
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                }
                .buttonStyle(.plain)
            }
            if list.isEmpty {
                Text("ぜんぶクリア！")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .partnerSoftCard()
            } else {
                VStack(spacing: 4) {
                    ForEach(list) { m in
                        PartnerProfileMissionRow(mission: m) { onAction(m.action) }
                    }
                }
                .padding(6)
                .partnerSoftCard()
            }
        }
    }

    // MARK: - あなたのこと

    private var youSection: some View {
        let waiting = found.filter(\.isWaiting).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("あなたのこと")
                    .font(.system(size: 16, weight: .bold))
                if waiting > 0 {
                    Text("返事待ち \(waiting)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(RenewalTokens.accentPink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(RenewalTokens.accentPink.opacity(0.1)))
                }
                Spacer()
                Text("\(found.count)/\(found.count + locked.count)")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
            }
            if found.isEmpty {
                HStack(spacing: 10) {
                    PartnerIconImage(size: 36)
                    Text("服をおぼえるほど、あなたのことを見つけて話せるようになるよ")
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .partnerSoftCard()
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(found) { d in
                    Button {
                        Haptic.impact(.soft)
                        openDiscoveryId = d.id
                    } label: { tile(d) }
                    .buttonStyle(.plain)
                }
                if let next = locked.first {
                    lockedTile(next)
                }
            }
        }
    }

    private func tile(_ d: PartnerProfileDiscovery) -> some View {
        let hue = PartnerHue(name: d.hue)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: d.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hue.ink)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white))
                Spacer()
                if d.isWaiting {
                    Circle().fill(RenewalTokens.accentPink).frame(width: 8, height: 8)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(hue.ink.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
            Text(d.short ?? d.headline ?? "")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
            Text([d.rarityLabel, d.date_label].compactMap { $0 }.joined(separator: " ・ "))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(hue.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(hue.wash))
        .accessibilityElement(children: .combine)
        .accessibilityHint(d.isWaiting ? "相棒に返事できます" : "")
    }

    private func lockedTile(_ d: PartnerProfileDiscovery) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.muted)
                .frame(width: 30, height: 30)
                .background(Circle().fill(RenewalTokens.surface))
            Spacer(minLength: 0)
            Text("あと\(locked.count)つ")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RenewalTokens.muted)
            Text(d.hint ?? "")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RenewalTokens.controlBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - 読み込み中・失敗・トースト

    private var loading: some View {
        VStack(spacing: 18) {
            Circle().fill(RenewalTokens.raised).frame(width: 124, height: 124)
            RoundedRectangle(cornerRadius: 8).fill(RenewalTokens.raised).frame(width: 90, height: 28)
            RoundedRectangle(cornerRadius: 20).fill(RenewalTokens.raised).frame(height: 64)
            RoundedRectangle(cornerRadius: 18).fill(RenewalTokens.raised).frame(height: 160)
        }
        .padding(20)
        .redacted(reason: .placeholder)
        .accessibilityLabel("相棒を読み込み中")
    }

    private var failed: some View {
        VStack(spacing: 12) {
            PartnerIconImage(size: 64)
            Text("うまく読み込めなかった")
                .font(.system(size: 15, weight: .semibold))
            Button("もう一度") { Task { await viewModel.load() } }
                .buttonStyle(RenewalPrimaryButtonStyle(filled: true))
                .frame(width: 160)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private func clearedToast(_ m: PartnerProfileMission) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundStyle(RenewalTokens.accentPink)
            VStack(alignment: .leading, spacing: 2) {
                Text("ミッションクリア ＋\(m.points)%")
                    .font(.system(size: 13, weight: .bold))
                Text(m.title)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .partnerSoftCard(16)
        .padding(.horizontal, 16)
    }
}
