import AppIntents
import SwiftData

/// Siri・ショートカット・アクションボタンから、アプリを開かずに一言記録する。
struct AddMemoIntent: AppIntent {
    static var title: LocalizedStringResource = "動静を記録"
    static var description = IntentDescription("やったことを記録")

    @Parameter(title: "やったこと", requestValueDialog: "やったこと")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = Store.container.mainContext
        context.insert(Entry(start: .now, text: text))
        try context.save()
        return .result(dialog: "記録しました")
    }
}

struct DoseiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddMemoIntent(),
            phrases: ["\(.applicationName)に記録", "\(.applicationName)でメモ"],
            shortTitle: "動静を記録",
            systemImageName: "pencil"
        )
    }
}
