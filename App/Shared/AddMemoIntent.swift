import AppIntents
import SwiftData

/// Siri・ショートカット・アクションボタンから、アプリを開かずに一言記録する。
struct AddMemoIntent: AppIntent {
    static var title: LocalizedStringResource = "動静を記録"
    static var description = IntentDescription("いまの時刻で、やったことを記録します。")

    @Parameter(title: "やったこと", requestValueDialog: "何をしていますか？")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedStore.container.mainContext
        context.insert(Entry(start: .now, text: text))
        try context.save()
        return .result(dialog: "記録しました")
    }
}

struct DosekiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddMemoIntent(),
            phrases: ["\(.applicationName)に記録", "\(.applicationName)でメモ"],
            shortTitle: "動静を記録",
            systemImageName: "pencil"
        )
    }
}
