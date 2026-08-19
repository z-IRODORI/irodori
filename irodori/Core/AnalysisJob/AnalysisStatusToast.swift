//
//  AnalysisStatusToast.swift
//  irodori
//
//  画面下に常駐する解析ステータストースター (幅 ≈ 画面の55%)。
//  解析中: スピナー + ✕ / 完了: タップで結果画面へ / 失敗: タップで再試行。
//  MainTabView の overlay(bottom) に置かれ、全タブ・push 先でも表示される。
//

import SwiftUI

struct AnalysisStatusToast: View {
    private var store = AnalysisJobStore.shared
    /// 完了トースタータップ時に結果画面へ遷移する (MainTabView が path へ push)
    var onOpenResult: (ViewType.CoordinateDetailParams) -> Void

    init(onOpenResult: @escaping (ViewType.CoordinateDetailParams) -> Void) {
        self.onOpenResult = onOpenResult
    }

    var body: some View {
        if let job = store.current {
            Button {
                handleTap(job)
            } label: {
                HStack(spacing: 10) {
                    thumbnailView

                    Text(statusText(job.status))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    switch job.status {
                    case .processing:
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    case .completed:
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    case .failed:
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    // ✕: ローカル追跡をやめる (解析中/失敗時のみ。完了はタップで消える)
                    if job.status != .completed {
                        Button {
                            Haptic.impact(.soft)
                            store.cancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: UIScreen.main.bounds.width * 0.5)
                .background(backgroundColor(job.status))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("analysis-status-toast")
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = store.thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 36, height: 36)
        }
    }

    private func statusText(_ status: AnalysisJobStore.Status) -> String {
        switch status {
        case .processing: return "コーデを解析中…"
        case .completed: return "解析が完了しました"
        case .failed: return "解析に失敗しました"
        }
    }

    private func backgroundColor(_ status: AnalysisJobStore.Status) -> Color {
        switch status {
        case .processing: return .black.opacity(0.88)
        case .completed: return .pink
        case .failed: return Color(red: 0.75, green: 0.2, blue: 0.2)
        }
    }

    private func handleTap(_ job: AnalysisJobStore.Job) {
        switch job.status {
        case .processing:
            break  // 解析中はタップしても何もしない (✕ で消せる)
        case .completed:
            guard let coordinateId = job.coordinateId else { return }
            Haptic.impact(.soft)
            onOpenResult(.init(
                coordinateId: coordinateId,
                coordinateImageURL: job.coordinateImageURL ?? "",
                showHeader: true
            ))
            store.clearAfterOpeningResult()
        case .failed:
            Task { await store.retry() }
        }
    }
}
