import Foundation
import SwiftData

/// 日記の1行。CloudKit 同期のため、すべてのプロパティに既定値を持たせ、unique 制約は使わない。
@Model
final class Entry {
    var start: Date = Date()
    var end: Date? = nil
    var text: String = ""
    var kindRaw: String = Kind.memo.rawValue
    /// 取り込んだ記録の出どころ（"swarm-<id>" など）。手で書いたものは nil。
    var sourceID: String? = nil
    /// 日記に載せない（Swarmのチェックインを隠したいときなど）
    var isHidden: Bool = false
    /// 手で直したら true。再取り込みで上書きしない。
    var userEdited: Bool = false
    var createdAt: Date = Date()

    init(start: Date, end: Date? = nil, text: String, kind: Kind = .memo, sourceID: String? = nil) {
        self.start = start
        self.end = end
        self.text = text
        self.kindRaw = kind.rawValue
        self.sourceID = sourceID
    }

    var kind: Kind {
        get { Kind(rawValue: kindRaw) ?? .memo }
        set { kindRaw = newValue.rawValue }
    }

    enum Kind: String, CaseIterable {
        case memo, wake, sleep, workout, checkin

        var symbol: String {
            switch self {
            case .memo: "pencil"
            case .wake: "sunrise"
            case .sleep: "moon.zzz"
            case .workout: "figure.outdoor.cycle"
            case .checkin: "mappin.and.ellipse"
            }
        }
    }
}
