//
//  PickScope.swift
//  irodori
//
//  ホーム「コーデ提案」の 今日/明日/週末 タブの日付ロジック。
//  バックエンド irodori-api/pick_dates.py と同一ルール:
//  タブ = [今日, 明日] + 今週末(土日)のうち今日・明日と重複しない最初の1日
//  (月〜木 → 今週土曜 / 金 → 日曜 / 土・日 → 週末タブ無し)。日付は全て JST。
//

import Foundation

enum PickScope: String, CaseIterable, Identifiable {
    case today
    case tomorrow
    case weekend

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "今日"
        case .tomorrow: return "明日"
        case .weekend: return "週末"
        }
    }
}

struct PickTab: Identifiable, Equatable {
    let scope: PickScope
    /// API に渡す対象日 (JST, yyyy-MM-dd)
    let dateString: String
    /// セグメントのラベル (例: 今日 / 明日(土) / 週末 8/1(土))
    let label: String
    /// 見出し横の短い日付表記 (例: 7/27(月))
    let shortDate: String

    var id: String { scope.rawValue }
}

enum PickTabBuilder {
    private static var jstCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        cal.locale = Locale(identifier: "ja_JP")
        return cal
    }

    /// 現在時刻から表示するタブを組み立てる
    static func visibleTabs(now: Date = Date()) -> [PickTab] {
        let cal = jstCalendar
        let today = cal.startOfDay(for: now)
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else { return [] }
        var tabs: [PickTab] = [
            tab(.today, date: today, cal: cal),
            tab(.tomorrow, date: tomorrow, cal: cal),
        ]
        // 今週末(土日)のうち今日・明日と重複しない最初の日 (backend pick_dates.py と同一)
        let weekday = cal.component(.weekday, from: today) // 日=1, 月=2, ... 土=7
        let offsetToWeekend: Int?
        switch weekday {
        case 2...5: offsetToWeekend = 7 - weekday   // 月〜木 → 今週土曜
        case 6: offsetToWeekend = 2                 // 金 → 日曜 (明日=土曜と重複)
        default: offsetToWeekend = nil              // 土・日 → 週末タブ無し
        }
        if let offset = offsetToWeekend,
           let weekendDay = cal.date(byAdding: .day, value: offset, to: today) {
            tabs.append(tab(.weekend, date: weekendDay, cal: cal))
        }
        return tabs
    }

    /// 初期選択タブ: JST 15時までは「今日」、それ以降は「明日」(帰宅後は翌日の計画をする文脈)
    static func defaultScope(now: Date = Date()) -> PickScope {
        jstCalendar.component(.hour, from: now) < 15 ? .today : .tomorrow
    }

    private static func tab(_ scope: PickScope, date: Date, cal: Calendar) -> PickTab {
        let isoFmt = DateFormatter()
        isoFmt.locale = Locale(identifier: "en_US_POSIX")
        isoFmt.timeZone = cal.timeZone
        isoFmt.dateFormat = "yyyy-MM-dd"

        let shortFmt = DateFormatter()
        shortFmt.locale = Locale(identifier: "ja_JP")
        shortFmt.timeZone = cal.timeZone
        shortFmt.dateFormat = "M/d(E)"

        let weekday = cal.component(.weekday, from: date)
        let short = shortFmt.string(from: date)
        let label: String
        switch scope {
        case .weekend:
            label = "週末 \(short)"
        default:
            // 今日・明日が土日に当たる日は「今日(土)」のように明示する
            let suffix: String
            switch weekday {
            case 7: suffix = "(土)"
            case 1: suffix = "(日)"
            default: suffix = ""
            }
            label = scope.displayName + suffix
        }
        return PickTab(scope: scope, dateString: isoFmt.string(from: date), label: label, shortDate: short)
    }
}
