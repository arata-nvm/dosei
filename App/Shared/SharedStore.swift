import Foundation
import SwiftData
import DosekiCore

enum SharedStore {
    /// アプリ本体とショートカット（App Intent）で同じ保存先を使う。
    /// cloudKitDatabase: .automatic で、entitlements の iCloud コンテナに同期される。
    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([Entry.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }()
}

/// 設定値（端末ごと）
enum AppSettings {
    static let subjectKey = "subject"
    static let boundaryHourKey = "boundaryHour"
    static let swarmClientIDKey = "swarmClientID"

    static var boundaryHour: Int {
        let v = UserDefaults.standard.object(forKey: boundaryHourKey) as? Int
        return v ?? 4
    }

    static var today: DiaryDay {
        DiaryDay(containing: Date(), boundaryHour: boundaryHour)
    }
}

extension DiaryDay {
    var startDate: Date { start(boundaryHour: AppSettings.boundaryHour) }
    var endDate: Date { end(boundaryHour: AppSettings.boundaryHour) }
}
