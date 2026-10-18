//
//  PartnerIntegratedHomeSandbox.swift
//  irodori
//
//  相棒統合ホーム画面の改善案サンドボックス。
//  「相棒をホーム画面に統合（相棒タップで相棒画面へ）」「ホーム画面の要素・階層の整理」を
//  3つのデザイン案（案A / 案B / 案C）で比較検証できる画面。
//

import SwiftUI
import Kingfisher

struct PartnerIntegratedHomeSandboxView: View {
    enum DesignPattern: String, CaseIterable, Identifiable {
        case patternA = "案A: バディ統合(推奨)"
        case patternB = "案B: 相棒カード＆大判"
        case patternC = "案C: 1画面凝縮"

        var id: String { rawValue }

        var summary: String {
            switch self {
            case .patternA:
                return "相棒ヘッダー＋吹き出しを最上部に統合し、カード内の重複アイコンやメタ行を排除。3案カルーセルと3タイル登録に絞った最もバランスの良い構成。"
            case .patternB:
                return "相棒の存在感（理解している特徴チップ付き）をカードとして見せ、イチオシの1案を大きく表示＋残りをサブ候補として並べる雑誌風構成。"
            case .patternC:
                return "スクロール量を最小化。相棒の一言バー・3案カルーセル・下部アクションバーを1画面に収め、迷わず即決できるストイックな構成。"
            }
        }
    }

    @State private var selectedPattern: DesignPattern = .patternA
    @State private var useRealAPI: Bool = true
    @State private var viewModel: HomeViewModel = HomeViewModel(apiClient: HomeClient())
    @State private var path: [ViewType] = []

    // シート・遷移管理
    @State private var showPartnerSheet = false
    @State private var showOnboardingSheet = false
    @State private var showFullBodyPicker = false
    @State private var showStandardItemPicker = false
    @State private var showKeywordSearch = false
    @State private var showTasteVote = false
    @State private var showingPrefecturePicker = false
    @State private var selectedReasonItem: DailyRecommendationItem? = nil
    @State private var currentCardID: String? = nil
    @State private var markingWornID: String? = nil

    private var daily: DailyRecommendationResponse? { viewModel.dailyRecommendation }
    private var cards: [DailyRecommendationItem] {
        Array(viewModel.displayRecommendations(for: viewModel.selectedPickScope).prefix(3))
    }

    private var partnerTypeName: String {
        if let name = viewModel.partnerHome?.type_name, !name.isEmpty { return name }
        if let name = viewModel.persistedOnboarding?.type_name, !name.isEmpty { return name }
        if let saved = UserDefaults.standard.string(forKey: UserDefaultsKey.partnerImage.rawValue), !saved.isEmpty {
            return saved
        }
        return "ナチュラル・パートナー"
    }

    private var partnerSubtitle: String {
        if let sub = viewModel.partnerHome?.partner_subtitle, !sub.isEmpty { return sub }
        if let sub = viewModel.persistedOnboarding?.partner_subtitle, !sub.isEmpty { return sub }
        return "あなたの好みと予定に寄り添う相棒"
    }

    private var partnerSpeech: String {
        if let c = daily?.partner_comment, !c.isEmpty { return c }
        if let reason = viewModel.partnerHome?.home_briefing, !reason.isEmpty { return reason }
        if let greeting = viewModel.partnerHome?.greeting, !greeting.isEmpty { return greeting }
        return "\(viewModel.selectedPickScope.displayName)の気温と手持ち服から、似合いそうな3案を選んだよ。"
    }

    private var displayTraits: [PartnerOnboardingTrait] {
        if let traits = viewModel.partnerHome?.traits, !traits.isEmpty { return traits }
        if let traits = viewModel.persistedOnboarding?.traits, !traits.isEmpty { return traits }
        return [
            PartnerOnboardingTrait(axis: "impression", axis_label: "なりたい印象", value: "soft", label: "優しくて、話しかけやすい"),
            PartnerOnboardingTrait(axis: "priority", axis_label: "大事にしたい感覚", value: "F", label: "ラクに動けて、着心地がいいこと"),
            PartnerOnboardingTrait(axis: "range", axis_label: "毎日の提案", value: "C", label: "手持ちの服で、安心できる着回し"),
            PartnerOnboardingTrait(axis: "tone", axis_label: "相棒の話し方", value: "gentle", label: "やさしく丁寧に")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            sandboxControlHeader

            switch selectedPattern {
            case .patternA:
                patternABody
            case .patternB:
                patternBBody
            case .patternC:
                patternCBody
            }
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.97))
        .navigationTitle("ホーム改善案 Sandbox")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reloadData()
        }
        .onChange(of: useRealAPI) { _, _ in
            Task { await reloadData() }
        }
        // 相棒タップ → 相棒画面を表示
        .sheet(isPresented: $showPartnerSheet) {
            NavigationStack(path: $path) {
                PartnerView(
                    path: $path,
                    onClose: { showPartnerSheet = false }
                )
                .navigationDestination(for: ViewType.self) { destination in
                    if case .generalChat(let convId) = destination {
                        GeneralChatView(
                            path: $path,
                            viewModel: GeneralChatViewModel(apiClient: ChatClient(), conversationId: convId)
                        )
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showOnboardingSheet) {
            PartnerOnboardingFlowView(
                showCloseButton: true,
                onComplete: {
                    showOnboardingSheet = false
                    Task { await reloadData() }
                }
            )
        }
        .fullScreenCover(isPresented: $showFullBodyPicker) {
            FullBodyPickerView(
                onComplete: { _ in showFullBodyPicker = false },
                onClose: { showFullBodyPicker = false }
            )
        }
        .sheet(isPresented: $showStandardItemPicker) {
            NavigationStack {
                SelectStandardItemView(
                    path: $path,
                    onComplete: { showStandardItemPicker = false }
                )
                .navigationTitle("定番アイテムから追加")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") { showStandardItemPicker = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showKeywordSearch) {
            NavigationStack {
                KeywordItemSearchView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") { showKeywordSearch = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showTasteVote) {
            NavigationStack {
                PartnerPattern4TasteVoteView()
                    .navigationTitle("2つのコーデを見比べる")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") { showTasteVote = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingPrefecturePicker) {
            NavigationStack {
                PrefecturePickerView(
                    selectedCode: viewModel.currentPrefectureCode,
                    onSelect: { prefecture in
                        Task { await viewModel.updatePrefecture(prefecture) }
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") { showingPrefecturePicker = false }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedReasonItem) { item in
            NavigationStack {
                TomorrowCompositionView(
                    item: item,
                    initialRating: viewModel.feedbackRating(for: item),
                    onFeedback: { rating, reasons in
                        await viewModel.sendFeedback(item: item, rating: rating, reasons: reasons)
                    },
                    onAddedToCalendar: { date in
                        viewModel.notePlanned(date: date, item: item, source: "home")
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") { selectedReasonItem = nil }
                    }
                }
            }
        }
    }

    private func reloadData() async {
        if useRealAPI {
            viewModel = HomeViewModel(apiClient: HomeClient())
        } else {
            viewModel = HomeViewModel(
                apiClient: MockHomeClient(),
                dailyRecommendationClient: MockDailyRecommendationClient()
            )
        }
        await viewModel.onAppear()
    }

    // MARK: - Sandbox 切り替えバー

    private var sandboxControlHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(DesignPattern.allCases) { pattern in
                    let isSelected = selectedPattern == pattern
                    Button {
                        Haptic.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPattern = pattern
                        }
                    } label: {
                        Text(pattern.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : .black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.black : Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    useRealAPI.toggle()
                } label: {
                    Text(useRealAPI ? "実API" : "Mock")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(useRealAPI ? Color.teal : Color.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((useRealAPI ? Color.teal : Color.orange).opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Text(selectedPattern.summary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // =========================================================================
    // MARK: - 案A: バディ統合・ミニマル型（推奨）
    // =========================================================================

    private var patternABody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 1. 相棒バディヘッダー（タップで相棒画面へ）
                patternAPartnerHeader
                    .padding(.horizontal, 20)

                // 2. 今日 / 明日 / 週末 ＋ 地域・天気 1行バー
                unifiedScopeAndWeatherBar
                    .padding(.horizontal, 20)

                // 3. スッキリした3案カルーセル（カード内の重複アイコン・不要メタ行なし）
                cleanOutfitCarousel

                // 4. コンパクト3タイル「相棒に手持ち服・好みを教える」
                compactDataAcquisitionSection
                    .padding(.horizontal, 20)

                // 5. 直近のコーデ記録（カレンダー連携）
                compactRecentCoordinatesSection
                    .padding(.horizontal, 20)

                Spacer().frame(height: 36)
            }
            .padding(.top, 16)
        }
    }

    /// 案Aの相棒ヘッダー: アバター＋名前＋吹き出しが一体になり、タップすると相棒画面を開く
    private var patternAPartnerHeader: some View {
        Button {
            Haptic.impact(.soft)
            showPartnerSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        PartnerIconImage(size: 52)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))

                        // タップ可能であることを示す小さなインジケータ
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.black)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(partnerTypeName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                            Text("相棒画面へ ›")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Text(partnerSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                // 相棒の今日の一言（吹き出し風ボックス）
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black.opacity(0.35))
                        .padding(.top, 2)

                    Text(partnerSpeech)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.85))
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // =========================================================================
    // MARK: - 案B: 相棒カード＆大判フォーカス型
    // =========================================================================

    private var patternBBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 相棒プロフィール＆理解チップ付きカード
                patternBPartnerHeroCard
                    .padding(.horizontal, 20)

                unifiedScopeAndWeatherBar
                    .padding(.horizontal, 20)

                // イチオシ1枚を大きく＋残り2案を下に横並び
                if let first = cards.first {
                    VStack(alignment: .leading, spacing: 14) {
                        featuredLargeCard(first)
                            .padding(.horizontal, 20)

                        if cards.count > 1 {
                            Text("ほかの候補")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                ForEach(Array(cards.dropFirst())) { subCard in
                                    compactSubCard(subCard)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                } else {
                    cleanOutfitCarousel
                }

                compactDataAcquisitionSection
                    .padding(.horizontal, 20)

                Spacer().frame(height: 36)
            }
            .padding(.top, 16)
        }
    }

    private var patternBPartnerHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Haptic.impact(.soft)
                showPartnerSheet = true
            } label: {
                HStack(spacing: 12) {
                    PartnerIconImage(size: 56)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("あなたの相棒")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.black)
                                .clipShape(Capsule())
                            Text("タップで詳細・相談 ›")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(partnerTypeName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Text(partnerSpeech)
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.85))
                .lineSpacing(3)

            // 理解している4つの特徴ピル
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(displayTraits) { trait in
                        HStack(spacing: 4) {
                            Text(trait.axis_label)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(trait.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func featuredLargeCard(_ card: DailyRecommendationItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                KFImage(URL(string: card.image_url))
                    .resizable()
                    .placeholder { Color.gray.opacity(0.15) }
                    .scaledToFill()
                    .frame(height: 360)
                    .frame(maxWidth: .infinity)
                    .clipped()

                Text("相棒のイチオシ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(12)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedReasonItem = card
            }

            VStack(alignment: .leading, spacing: 10) {
                if let reason = card.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black)
                        .lineSpacing(3)
                }

                HStack(spacing: 10) {
                    Button {
                        selectedReasonItem = card
                    } label: {
                        Text("詳細・内訳")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 100)
                            .padding(.vertical, 11)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        adoptCard(card)
                    } label: {
                        Text("このコーデにする")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func compactSubCard(_ card: DailyRecommendationItem) -> some View {
        Button {
            selectedReasonItem = card
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                KFImage(URL(string: card.image_url))
                    .resizable()
                    .placeholder { Color.gray.opacity(0.15) }
                    .scaledToFill()
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(card.reason ?? "手持ち服で組める候補")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // =========================================================================
    // MARK: - 案C: 1画面凝縮・ストイック型
    // =========================================================================

    private var patternCBody: some View {
        VStack(spacing: 12) {
            // コンパクトな相棒バー（1行＋吹き出し）
            Button {
                Haptic.impact(.soft)
                showPartnerSheet = true
            } label: {
                HStack(spacing: 10) {
                    PartnerIconImage(size: 40)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(partnerSpeech)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.black)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            unifiedScopeAndWeatherBar
                .padding(.horizontal, 20)

            cleanOutfitCarousel

            Spacer(minLength: 0)

            // 下部固定のデータ登録ドック
            HStack(spacing: 8) {
                Button {
                    showFullBodyPicker = true
                } label: {
                    Label("写真から登録", systemImage: "photo.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    showStandardItemPicker = true
                } label: {
                    Label("定番服", systemImage: "tshirt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showTasteVote = true
                } label: {
                    Label("2択診断", systemImage: "heart.text.square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    // =========================================================================
    // MARK: - 共通コンポーネント（整理されたスコープバー・カルーセル・3タイル登録）
    // =========================================================================

    /// 今日 / 明日 / 週末 の切替と、日付・地域・天気を1行に凝縮したバー
    private var unifiedScopeAndWeatherBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // スコープ切り替えピル
            HStack(spacing: 4) {
                ForEach(viewModel.pickTabs) { tab in
                    let isSelected = tab.scope == viewModel.selectedPickScope
                    Button {
                        Haptic.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectPickScope(tab.scope)
                        }
                    } label: {
                        Text(tab.scope.displayName)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : .black.opacity(0.65))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.black : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.gray.opacity(0.12))
            .clipShape(Capsule())

            Spacer(minLength: 4)

            // 地域＋天気コンパクトバッジ
            Button {
                Haptic.impact(.soft)
                showingPrefecturePicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.currentPrefectureName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let weather = daily?.weather {
                        DailyMiniWeatherBadge(weather: weather)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// 重複アイコンやノイズを排除したクリーンな3案カルーセル
    @ViewBuilder
    private var cleanOutfitCarousel: some View {
        if viewModel.isLoadingDailyRecommendation && cards.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white)
                            .frame(width: 264, height: 430)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        } else if cards.isEmpty {
            VStack(spacing: 10) {
                Text("コーデ提案を準備しています")
                    .font(.system(size: 14, weight: .semibold))
                Button("再読み込み") {
                    Task { await viewModel.reloadDailyRecommendation() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black)
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        cleanPlanCard(card, rank: index + 1)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentCardID)
        }
    }

    private func cleanPlanCard(_ card: DailyRecommendationItem, rank: Int) -> some View {
        let isDecided = viewModel.pickTabs
            .first { $0.scope == viewModel.selectedPickScope }
            .flatMap { viewModel.decidedPoolId(forDate: $0.dateString) } == card.pool_id

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                KFImage(URL(string: card.image_url))
                    .resizable()
                    .placeholder { Color.gray.opacity(0.12) }
                    .scaledToFill()
                    .frame(width: 264, height: 320)
                    .clipped()

                HStack {
                    Text(rank == 1 ? "イチオシ" : "候補 \(rank)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(rank == 1 ? .white : .black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(rank == 1 ? Color.black.opacity(0.85) : Color.white.opacity(0.9))
                        .clipShape(Capsule())

                    Spacer()

                    if !card.owned_items.isEmpty {
                        Text("手持ち \(card.owned_items.count)点")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.92))
                            .clipShape(Capsule())
                    }
                }
                .padding(10)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptic.selection()
                selectedReasonItem = card
            }

            VStack(alignment: .leading, spacing: 10) {
                // 相棒アイコンは重複させず、提案理由をシンプルに2行で表示
                Text(card.reason ?? "\(viewModel.selectedPickScope.displayName)の気候とあなたの好みに合わせた提案です")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.82))
                    .lineSpacing(2.5)
                    .lineLimit(2, reservesSpace: true)

                HStack(spacing: 8) {
                    Button {
                        Haptic.impact(.soft)
                        selectedReasonItem = card
                    } label: {
                        Text("内訳")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 68)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        adoptCard(card)
                    } label: {
                        HStack(spacing: 5) {
                            if isDecided {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(isDecided ? "決定ずみ" : "これにする")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isDecided ? Color.black.opacity(0.45) : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDecided || markingWornID != nil)
                }
            }
            .padding(12)
        }
        .frame(width: 264)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    /// 相棒を育てるデータ獲得セクション（3タイル横並びでコンパクトに）
    private var compactDataAcquisitionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("相棒に手持ち服・好みを教える")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Text("登録 \(viewModel.closetItems.count)点")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                compactActionTile(
                    icon: "photo.on.rectangle.angled",
                    title: "写真から検出",
                    subtitle: "全身写真をAI選択",
                    isPrimary: true,
                    action: { showFullBodyPicker = true }
                )

                compactActionTile(
                    icon: "tshirt",
                    title: "定番・検索",
                    subtitle: "写真なしで追加",
                    isPrimary: false,
                    action: { showStandardItemPicker = true }
                )

                compactActionTile(
                    icon: "heart.text.square",
                    title: "2択で好み",
                    subtitle: "直感で選ぶだけ",
                    isPrimary: false,
                    action: { showTasteVote = true }
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func compactActionTile(
        icon: String,
        title: String,
        subtitle: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isPrimary ? .white : .black)
                    .frame(width: 34, height: 34)
                    .background(isPrimary ? Color.black : Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// 直近のコーデ記録（シンプル横スクロール）
    private var compactRecentCoordinatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近のコーデ記録")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Text("\(viewModel.homeResponse.recent_coordinates.count)件")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if viewModel.homeResponse.recent_coordinates.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                    Text("「これにする」やカメラ撮影で記録したコーデがここに並びます")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.homeResponse.recent_coordinates.prefix(8), id: \.id) { coord in
                            KFImage(URL(string: coord.displayImageURL))
                                .resizable()
                                .placeholder { Color.gray.opacity(0.12) }
                                .scaledToFill()
                                .frame(width: 84, height: 112)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private func adoptCard(_ card: DailyRecommendationItem) {
        Haptic.impact(.medium)
        markingWornID = card.id
        Task {
            let ok = await viewModel.markWorn(item: card)
            markingWornID = nil
            if ok {
                if let tab = viewModel.pickTabs.first(where: { $0.scope == viewModel.selectedPickScope }) {
                    viewModel.recordDecision(poolId: card.pool_id, targetDate: tab.dateString)
                }
                ToastManager.shared.show("\(viewModel.selectedPickScope.displayName)のコーデに決定しました", style: .normal)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PartnerIntegratedHomeSandboxView()
            .environment(MainTabViewModel())
            .environment(FavoritesStore())
    }
}
