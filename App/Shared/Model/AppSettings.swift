import Foundation
import DoseiCore

/// 設定値（端末ごと、UserDefaults）。画面では同じキーを @AppStorage で使う。
enum AppSettings {
    enum Key {
        static let subject = "subject"
        static let boundaryHour = "boundaryHour"
        static let swarmClientID = "swarmClientID"
    }

    static let defaultBoundaryHour = 4
    static let nikkyURL = URL(string: "https://nikky.slimalized.dev/")!

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
