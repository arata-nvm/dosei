import DoseiCore
import Foundation
import SwiftData

/// 日記の1行。
///
/// CloudKit で同期するため、すべてのプロパティに既定値を持たせ、unique 制約は使わない。
/// 保存される項目なので、名前や型を変えるときは同期済みのデータに注意する。
@Model
final class Entry {
    var start: Date = Date()
    var end: Date? = nil
    var text: String = ""
    var kindRaw: String = RecordKind.memo.rawValue
    /// 取り込んだ記録の出どころ（SourceID）。手で書いたものは nil。
    var sourceID: String? = nil
    /// 日記に載せない
    var isHidden: Bool = false
    /// 手で直したら true。再取り込みで上書きしない。
    var userEdited: Bool = false
    var createdAt: Date = Date()

    init(start: Date, end: Date? = nil, text: String, kind: RecordKind = .memo, sourceID: String? = nil) {
        self.start = start
        self.end = end
        self.text = text
        self.kindRaw = kind.rawValue
        self.sourceID = sourceID
    }
}

// MARK: - 振る舞い

extension Entry {
    convenience init(_ record: ImportedRecord) {
        self.init(
            start: record.start, end: record.end, text: record.text,
            kind: record.kind, sourceID: record.sourceID)
    }

    var kind: RecordKind {
        get { RecordKind(rawValue: kindRaw) ?? .memo }
        set { kindRaw = newValue.rawValue }
    }

    /// 取り込んだ記録は、消しても次の取り込みで戻ってくるので、削除ではなく隠す。
    var isImported: Bool { sourceID != nil }

    /// 「ここまで」で終了時刻を付けられるか
    var canFinish: Bool { end == nil && kind == .memo }

    func finish(at date: Date = .now) {
        end = max(date, start)
        userEdited = true
    }

    /// 取り込み直した内容で更新する（手で直していれば何もしない）
    func update(from record: ImportedRecord) {
        guard !userEdited else { return }
        start = record.start
        end = record.end
        text = record.text
    }

    var timelineItem: TimelineItem {
        TimelineItem(start: start, end: end, text: text, link: SourceID.link(for: sourceID))
    }

    /// その日の記録
    static func on(_ day: DiaryDay, includeHidden: Bool = true) -> Predicate<Entry> {
        let from = day.startDate, to = day.endDate
        if includeHidden {
            return #Predicate<Entry> { $0.start >= from && $0.start < to }
        }
        return #Predicate<Entry> { $0.start >= from && $0.start < to && !$0.isHidden }
    }
}
