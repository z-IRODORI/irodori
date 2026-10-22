//
//  PartnerProfileDesignE.swift
//  irodori - Sandbox
//
//  案E「シンプル + 週報」— 一つ前の案D (シンプル) を土台に、案D (週報) の色とストーリーを少しだけ足した形。
//  ・上: 理解度の輪と段階の点 (シンプル版のまま)
//  ・その下: 今週のふりかえり (週報) を細い帯で。タップでストーリーを再生
//  ・次のミッション (シンプル版のまま)
//  ・あなたのこと: 2列のタイルはそのままに、中身を「相棒の発見」に。発見ごとの色で塗り、
//    返事待ちには小さな印。タップで「なんで？」→ 返事の深掘りシート
//

import SwiftUI

struct PartnerProfileDesignE: View {
    @Bindable var store: PartnerProfileSandboxStore
    @Bindable var discoveries: PartnerDiscoveryState
    @State private var showAllMissions = false
    @State private var openCard: PartnerDiscovery?
    @State private var playing = false
    @State private var gauge: CGFloat = 0

    private var found: [PartnerDiscovery] { discoveries.discoveries(pct: store.pct) }
    private var upcoming: [PartnerDiscovery] { discoveries.upcoming(pct: store.pct) }

    /// タイルに出す短い言葉 (発見の見出しを縮めたもの)
    private static let shortTitle: [String: String] = [
        "hidden_color": "いいねは色もの",
        "black_fast": "黒だと即決",
        "friday": "金曜は明るめ",
        "denim_hero": "主役はジーンズ",
        "cold_switch": "20℃で黒が増える",
        "orange_area": "オレンジは小物なら",
        "rotation": "上は続けない派",
        "white_shirt": "白シャツは勝負服",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if !found.isEmpty { weeklyStrip }
                missions
                youSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.ground)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { gauge = CGFloat(store.pct) / 100 } }
        .onChange(of: store.pct) { _, v in withAnimation(.easeOut(duration: 0.5)) { gauge = CGFloat(v) / 100 } }
        .sheet(item: $openCard) { d in
            PartnerDiscoverySheet(discovery: d, discoveries: discoveries)
                .presentationDetents([.fraction(0.66), .large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showAllMissions) {
            PartnerAllMissionsSheet(store: store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .fullScreenCover(isPresented: $playing) {
            PartnerStoryPlayer(discoveries: Array(found.prefix(3)), state: discoveries)
        }
    }

    // MARK: - 理解度 (シンプル版のまま)

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(RenewalTokens.rule, lineWidth: 7)
                Circle().trim(from: 0, to: gauge)
                    .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                PartnerIconImage(size: 92)
            }
            .frame(width: 124, height: 124)

            VStack(spacing: 4) {
                Text("\(store.pct)%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("相棒の理解度")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(PartnerMissionCatalog.stages, id: \.index) { s in
                        Capsule()
                            .fill(store.pct >= s.at_pct ? RenewalTokens.ink : RenewalTokens.border)
                            .frame(width: store.stage.index == s.index ? 22 : 8, height: 8)
                    }
                }
                HStack(spacing: 6) {
                    Text(store.stage.name)
                        .font(.system(size: 13, weight: .semibold))
                    if let next = store.nextStage {
                        Text("あと\(next.at_pct - store.pct)%で\(next.name)")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.4), value: store.pct)
    }

    // MARK: - 今週のふりかえり (週報を細い帯で)

    private var weeklyStrip: some View {
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
                    Text("\(found.count)つ見つけたよ ・ 10/16〜10/22")
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
                // 見つけた発見の色を小さな丸で
                HStack(spacing: -5) {
                    ForEach(found.prefix(4)) { d in
                        Circle().fill(d.hue.wash)
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
        .accessibilityLabel("今週のふりかえりを見る。\(found.count)つの発見")
    }

    // MARK: - 次のミッション (シンプル版のまま)

    private var missions: some View {
        let list = Array(store.activeMissions.prefix(3))
        let cleared = PartnerMissionCatalog.all.filter(store.isDone).count
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
                        Text("実績 \(cleared)/\(PartnerMissionCatalog.all.count)")
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
                    ForEach(list) { m in PartnerSoftMissionRow(mission: m, store: store) }
                }
                .padding(6)
                .partnerSoftCard()
            }
        }
    }

    // MARK: - あなたのこと (発見のタイル)

    private var youSection: some View {
        let waiting = found.filter { discoveries.answers[$0.id] == nil }.count
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
                Text("\(found.count)/\(PartnerDiscoveryCatalog.all.count)")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(found) { d in
                    Button {
                        Haptic.impact(.soft)
                        _ = discoveries.opened.insert(d.id)
                        openCard = d
                    } label: { tile(d) }
                    .buttonStyle(.plain)
                }
                if let next = upcoming.first {
                    lockedTile(next)
                }
            }
        }
    }

    private func tile(_ d: PartnerDiscovery) -> some View {
        let waiting = discoveries.answers[d.id] == nil
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: d.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(d.hue.ink)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white))
                Spacer()
                if waiting {
                    Circle().fill(RenewalTokens.accentPink).frame(width: 8, height: 8)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(d.hue.ink.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
            Text(Self.shortTitle[d.id] ?? d.headline)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
            Text(d.rarity == .normal ? d.date : "\(d.rarity.rawValue) ・ \(d.date)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(d.hue.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(d.hue.wash))
        .accessibilityElement(children: .combine)
        .accessibilityHint(waiting ? "返事できます" : "")
    }

    private func lockedTile(_ d: PartnerDiscovery) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.muted)
                .frame(width: 30, height: 30)
                .background(Circle().fill(RenewalTokens.surface))
            Spacer(minLength: 0)
            Text("あと\(upcoming.count)つ")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RenewalTokens.muted)
            Text("理解度 \(d.unlockAt)%で")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(RenewalTokens.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RenewalTokens.controlBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }
}
