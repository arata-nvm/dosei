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
    @State private var copied = false

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
            VStack(alignment: .leading, spacing: 8) {
                Text("ここで直してからコピーできます（元の記録は変わりません）")
                    .font(.footnote).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                HStack {
                    Button("作り直す", action: rebuild)
                    Spacer()
                    Button(copied ? "コピーしました" : "コピー", action: copy)
                        .buttonStyle(.bordered)
                    Button("コピーしてNikkyを開く") {
                        copy()
                        openURL(Self.nikkyURL)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("\(day.title())の動静")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
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
        copied = false
    }

    private func copy() {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        copied = true
    }
}
