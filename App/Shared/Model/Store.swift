import SwiftData

enum Store {
    /// アプリ本体・ショートカット・バックグラウンドの取り込みで同じ保存先を使う。
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
