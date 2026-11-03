import SwiftUI
import SwiftData
import DoseiCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// その日の記録を首相動静風の文章にして、コピーしてNikkyに貼る。
struct SummaryView: View {
    let day: DiaryDay
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.subjectKey) private var subject = ""
    @Query private var entries: [Entry]
    @State private var text = ""

    static let nikkyURL = URL(string: "https://nikky.slimalized.dev/")!

    init(day: DiaryDay) {
        self.day = day
        let from = day.startDate, to = day.endDate
        _entries = Query(
            filter: #Predicate<Entry> { $0.start >= from && $0.start < to && !$0.isHidden },
            sort: \Entry.start
        )
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
                    ToolbarItem {
                        Button("リセット", systemImage: "arrow.counterclockwise", action: rebuild)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("コピーしてNikkyを開く") {
                            copy()
                            openURL(Self.nikkyURL)
                        }
                    }
                }
        }
        .onAppear(perform: rebuild)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }

    private func rebuild() {
        let items = entries.map { TimelineItem(start: $0.start, end: $0.end, text: $0.text) }
        let formatter = DoseiFormatter(subject: subject.isEmpty ? nil : subject)
        text = formatter.format(items)
    }

    private func copy() {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
