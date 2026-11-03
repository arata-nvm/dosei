import SwiftUI
import SwiftData

@main
struct DoseiApp: App {
    init() {
        #if os(iOS)
        // バックグラウンドで起こされたときも含め、起動のたびにヘルスケアの監視を登録し直す
        HealthBackground.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(SharedStore.container)
        #if os(macOS)
        .defaultSize(width: 520, height: 720)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

struct RootView: View {
    var body: some View {
        NavigationStack {
            TodayView()
        }
    }
}
