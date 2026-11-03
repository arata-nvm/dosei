import Foundation

/// 開始と終了のある時間（睡眠の1区間など）
public struct TimeSpan: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Apple Watch の睡眠記録（細切れの「睡眠中」区間）から起床・就寝時刻を求める。
public enum SleepAnalyzer {
    /// 間隔が maxGap 以下の区間をつないで、ひと続きの睡眠にまとめる。
    public static func sessions(_ intervals: [TimeSpan], maxGap: TimeInterval = 60 * 60) -> [TimeSpan] {
        let sorted = intervals.sorted { $0.start < $1.start }
        var result: [TimeSpan] = []
        for iv in sorted {
            if var last = result.last, iv.start.timeIntervalSince(last.end) <= maxGap {
                last.end = max(last.end, iv.end)
                result[result.count - 1] = last
            } else {
                result.append(iv)
            }
        }
        return result
    }

    /// その日の起床（朝の睡眠の終わり）と就寝（夜の睡眠の始まり）。
    /// 昼寝に引っ張られないよう、候補の中で一番長い睡眠を選ぶ。
    public static func wakeAndBed(
        sessions: [TimeSpan],
        day: DiaryDay,
        boundaryHour: Int = 4,
        calendar: Calendar = DoseiFormatter.japaneseCalendar
    ) -> (wake: Date?, bed: Date?) {
        let dayStart = day.start(boundaryHour: boundaryHour, calendar: calendar)
        let h: (Double) -> Date = { dayStart.addingTimeInterval($0 * 3600) }

        // 起床: 区切り〜その12時間後（既定で午前4時〜午後4時）に終わった睡眠
        let wakeSession = sessions
            .filter { $0.end >= dayStart && $0.end < h(12) }
            .max { $0.duration < $1.duration }

        // 就寝: 区切りの14時間後〜26時間後（既定で午後6時〜翌午前6時）に始まった睡眠
        let bedSession = sessions
            .filter { $0.start >= h(14) && $0.start < h(26) }
            .max { $0.duration < $1.duration }

        return (wakeSession?.end, bedSession?.start)
    }
}
