//
//  DecisionSendoffView.swift
//  irodori
//
//  「これにする」直後の見送り画面 (決定の儀式)。
//  最大の達成モーメントを無音にしない: ミニカード + チェックのスプリング +
//  相棒の一言 + (初回のみ) 通知許可の文脈付きプリプロンプト。
//

import SwiftUI
import Kingfisher

struct DecisionSendoffView: View {
    let item: DailyRecommendationItem
    /// バッチ生成済みの相棒コメント (無ければ天気テンプレにフォールバック)
    let partnerComment: String?
    let weather: DailyRecommendationWeather?
    /// タブ名 (今日 / 明日 / 週末)
    let scopeName: String

    @Environment(\.dismiss) private var dismiss
    @State private var checkVisible = false
    @State private var showNotificationPrompt = false
    @State private var isRequestingPermission = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    checkmark
                        .padding(.top, 28)

                    Text("\(scopeName)のコーデ、これで決まり")
                        .font(.system(size: 18, weight: .bold))

                    KFImage(URL(string: item.image_url))
                        .resizable()
                        .placeholder { Color.gray.opacity(0.15) }
                        .scaledToFill()
                        .frame(width: 168, height: 210)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)

                    // 決定はカレンダーの予定コーデにも反映される (HomeViewModel.markWorn)
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                        Text("カレンダーにも入れておいたよ")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 8) {
                        PartnerIconImage(size: 36)
                        DailyPartnerCommentBox(text: sendoffComment)
                    }
                    .padding(.horizontal, 24)

                    if showNotificationPrompt {
                        notificationPromptCard
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                Haptic.impact(.soft)
                dismiss()
            } label: {
                Text("ホームに戻る")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.gray.opacity(0.06))
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.1)) {
                checkVisible = true
            }
        }
        .task {
            // 通知許可は「決定の達成感の直後」という文脈で1回だけ求める
            let alreadyShown = UserDefaults.standard.bool(
                forKey: UserDefaultsKey.notificationPromptShown.rawValue
            )
            guard !alreadyShown else { return }
            let status = await NotificationManager.shared.authorizationStatus()
            if status == .notDetermined {
                withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
                    showNotificationPrompt = true
                }
            }
        }
    }

    // MARK: - チェックのスプリング

    private var checkmark: some View {
        ZStack {
            Circle()
                .fill(.black)
                .frame(width: 64, height: 64)
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(checkVisible ? 1.0 : 0.3)
        .opacity(checkVisible ? 1 : 0)
    }

    // MARK: - 相棒の一言

    private var sendoffComment: String {
        if let comment = partnerComment, !comment.isEmpty {
            return comment
        }
        if let weather {
            return "最高\(weather.max_temp)°の\(weather.condition)。この選択、いいと思う。いってらっしゃい！"
        }
        return "いい選択だと思う。いってらっしゃい！"
    }

    // MARK: - 通知許可の文脈付きプリプロンプト

    private var notificationPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("明日の支度ができたら、夜にそっと知らせようか？")
                .font(.system(size: 14, weight: .semibold))
            Text("毎日21時ごろ、明日の3コーデがそろったことをお知らせします")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    Haptic.impact(.light)
                    acceptNotification()
                } label: {
                    Text(isRequestingPermission ? "設定中..." : "知らせて")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRequestingPermission)
                Button {
                    declineNotification()
                } label: {
                    Text("今はいい")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .disabled(isRequestingPermission)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func acceptNotification() {
        isRequestingPermission = true
        Task { @MainActor in
            let granted = await NotificationManager.shared.requestAuthorization()
            UserDefaults.standard.set(true, forKey: UserDefaultsKey.notificationPromptShown.rawValue)
            isRequestingPermission = false
            withAnimation(.easeOut(duration: 0.25)) { showNotificationPrompt = false }
            if granted {
                await NotificationManager.shared.scheduleEveningTeaser(body: nil)
                ToastManager.shared.show("21時ごろにお知らせするね", style: .normal)
            }
        }
    }

    private func declineNotification() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.notificationPromptShown.rawValue)
        withAnimation(.easeOut(duration: 0.25)) { showNotificationPrompt = false }
    }
}

#Preview("見送り画面") {
    DecisionSendoffView(
        item: DailyRecommendationResponse.mock().recommendations[0],
        partnerComment: "明日は過ごしやすいから、ライトに春らしくいこう！",
        weather: DailyRecommendationResponse.mock().weather,
        scopeName: "今日"
    )
}
