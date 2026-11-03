import SwiftUI
import SwiftData
import DoseiCore

/// その日の記録を首相動静の文体にして、コピーしてNikkyに貼る。
struct SummaryView: View {
    let day: DiaryDay
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.Key.subject) private var subject = ""
    @Query private var entries: [Entry]
    @State private var text = ""

    init(day: DiaryDay) {
        self.day = day
        _entries = Query(filter: Entry.on(day, includeHidden: false), sort: \Entry.start)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.body)
                .padding()
                .navigationTitle(day.title())
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("コピーしてNikkyを開く") {
                            Pasteboard.copy(text)
                            openURL(AppSettings.nikkyURL)
                        }
                    }
                }
        }
        // 開くたびに、その日の記録から作る
        .onAppear(perform: rebuild)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }

    private func rebuild() {
        let formatter = DoseiFormatter(subject: subject.isEmpty ? nil : subject)
        text = formatter.format(entries.map(\.timelineItem))
    }
}
