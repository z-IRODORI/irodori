import SwiftUI
import Combine

@Observable
@MainActor
class PlannerViewModel {
    var calendarList: [CalendarData] = []
    var selectedDateID: Int?
    var selectedTab: Int = 0

    private let calendar = Calendar.current

    init() {
        generateCalendar()
        setInitialSelection()
    }

    // 現在の週（月〜日）を生成
    private func generateCalendar() {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

        self.calendarList = (0..<7).map { i in
            CalendarData(id: i, date: calendar.date(byAdding: .day, value: i, to: monday)!)
        }
    }

    // 初期選択を「今日」にセット
    private func setInitialSelection() {
        let weekday = calendar.component(.weekday, from: Date())
        self.selectedDateID = (weekday + 5) % 7
    }

    // 相対表示テキストの計算
    var relativeDateText: String {
        guard let id = selectedDateID, id < calendarList.count else { return "今日" }
        let targetDate = calendar.startOfDay(for: calendarList[id].date)
        let today = calendar.startOfDay(for: Date())
        let diff = calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0

        if diff == 0 { return "今日" }
        return diff > 0 ? "\(diff)日後" : "\(abs(diff))日前"
    }

    // 今月かどうかの判定
    func isCurrentMonth(date: Date) -> Bool {
        calendar.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    // アクション: 今日へ戻る
    func scrollToToday() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            setInitialSelection()
        }
    }

    // アクション: 日付選択
    func selectDate(id: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedDateID = id
        }
    }
}
