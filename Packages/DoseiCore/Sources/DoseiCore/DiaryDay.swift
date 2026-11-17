import Foundation

/// 「その日の日記」が扱う時間帯。深夜の就寝を前日扱いにするため、
/// 区切りを午前0時ではなく boundaryHour（既定は午前4時）に置く。
public struct DiaryDay: Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// date がどの日記の日に属するか。
    /// 時計の上の時で比べる（4時間を引くと、夏時間の切り替わる日に1時間ずれる）。
    public init(containing date: Date, boundaryHour: Int = 4, calendar: Calendar = DoseiFormatter.diaryCalendar) {
        let c = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let day = DiaryDay(year: c.year!, month: c.month!, day: c.day!)
        self = c.hour! < boundaryHour ? day.adding(days: -1, calendar: calendar) : day
    }

    public func start(boundaryHour: Int = 4, calendar: Calendar = DoseiFormatter.diaryCalendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: boundaryHour))!
    }

    public func end(boundaryHour: Int = 4, calendar: Calendar = DoseiFormatter.diaryCalendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: start(boundaryHour: boundaryHour, calendar: calendar))!
    }

    public func adding(days: Int, calendar: Calendar = DoseiFormatter.diaryCalendar) -> DiaryDay {
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        let moved = calendar.date(byAdding: .day, value: days, to: noon)!
        let c = calendar.dateComponents([.year, .month, .day], from: moved)
        return DiaryDay(year: c.year!, month: c.month!, day: c.day!)
    }

    /// その日の日記の中での「時:分」の日時。区切りより前の時刻（深夜）は、暦の上では翌日になる。
    public func date(
        hour: Int, minute: Int, boundaryHour: Int = 4,
        calendar: Calendar = DoseiFormatter.diaryCalendar
    ) -> Date {
        let calendarDay = hour < boundaryHour ? adding(days: 1, calendar: calendar) : self
        return calendar.date(
            from: DateComponents(
                year: calendarDay.year, month: calendarDay.month, day: calendarDay.day, hour: hour, minute: minute))!
    }

    /// 「11月3日（火）」
    public func title(calendar: Calendar = DoseiFormatter.diaryCalendar) -> String {
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        let weekday = calendar.component(.weekday, from: noon)
        let names = ["日", "月", "火", "水", "木", "金", "土"]
        return "\(month)月\(day)日（\(names[weekday - 1])）"
    }

    /// Swarm や HealthKit の取り込みで使う識別子用（"2026-11-03"）
    public var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
