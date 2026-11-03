import SwiftUI
import SwiftData

@main
struct DoseiApp: App {
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
