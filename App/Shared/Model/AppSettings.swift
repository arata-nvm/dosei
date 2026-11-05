import DoseiCore
import Foundation

/// 設定値（端末ごと、UserDefaults）。画面では同じキーを @AppStorage で使う。
enum AppSettings {
    enum Key {
        static let nikkyID = "nikkyID"
        static let boundaryHour = "boundaryHour"
        static let swarmClientID = "swarmClientID"
        static let spotifyClientID = "spotifyClientID"
    }

    static let defaultBoundaryHour = 4
    /// Nikky の投稿画面（ID がなければトップ）
    static func nikkyNewPostURL(id: String) -> URL {
        let base = URL(string: "https://nikky.slimalized.dev/")!
        // 「@arata」のように @ 付きで入れても、なしで入れても同じにする
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard !id.isEmpty,
            let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return base }
        return URL(string: "@\(escaped)/posts/new", relativeTo: base)?.absoluteURL ?? base
    }

    static var boundaryHour: Int {
        UserDefaults.standard.object(forKey: Key.boundaryHour) as? Int ?? defaultBoundaryHour
    }

    static var today: DiaryDay {
        DiaryDay(containing: Date(), boundaryHour: boundaryHour)
    }
}

extension DiaryDay {
    /// 設定の区切り時刻での、その日の始まりと終わり
    var startDate: Date { start(boundaryHour: AppSettings.boundaryHour) }
    var endDate: Date { end(boundaryHour: AppSettings.boundaryHour) }
}
