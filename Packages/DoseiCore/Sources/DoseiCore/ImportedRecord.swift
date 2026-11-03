import Foundation

/// 日記の1行の種類。アプリの Entry に文字列で保存されるので、rawValue は変えない。
public enum RecordKind: String, CaseIterable, Sendable {
    case memo, wake, sleep, workout, checkin
}

/// Swarm やヘルスケアから取り込んだ1件。アプリはこれを Entry として保存する。
public struct ImportedRecord: Equatable, Sendable {
    /// 取り込み元での ID。同じ記録を何度取り込んでも1行にするために使う。
    public var sourceID: String
    public var kind: RecordKind
    public var start: Date
    public var end: Date?
    public var text: String

    public init(sourceID: String, kind: RecordKind, start: Date, end: Date? = nil, text: String) {
        self.sourceID = sourceID
        self.kind = kind
        self.start = start
        self.end = end
        self.text = text
    }
}

/// sourceID の付け方。保存済みのデータと対応しているので、形式は変えない。
public enum SourceID {
    public static func swarm(_ checkinID: String) -> String { "swarm-\(checkinID)" }
    public static func wake(_ day: DiaryDay) -> String { "hk-wake-\(day.key)" }
    public static func bed(_ day: DiaryDay) -> String { "hk-bed-\(day.key)" }
    public static func workout(_ uuid: UUID) -> String { "hk-workout-\(uuid.uuidString)" }
}

extension ImportedRecord {
    /// 起床・就寝の2行（取れたものだけ）
    public static func sleep(wake: Date?, bed: Date?, day: DiaryDay) -> [ImportedRecord] {
        var records: [ImportedRecord] = []
        if let wake {
            records.append(.init(sourceID: SourceID.wake(day), kind: .wake, start: wake, text: "起床"))
        }
        if let bed {
            records.append(.init(sourceID: SourceID.bed(day), kind: .sleep, start: bed, text: "就寝"))
        }
        return records
    }
}
