import SwiftUI
import SwiftData
import DoseiCore

/// その日の記録の一覧。@Query の条件に日付を入れるため、日付ごとに作る。
struct DayEntriesList: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    @Binding var editing: Entry?

    init(day: DiaryDay, editing: Binding<Entry?>) {
        _entries = Query(filter: Entry.on(day), sort: \Entry.start)
        _editing = editing
    }

    var body: some View {
        List(entries) { entry in
            EntryRow(entry: entry)
                .contentShape(Rectangle())
                .onTapGesture { editing = entry }
                .contextMenu { menu(for: entry) }
        }
    }

    /// 長押し（Mac は右クリック）のメニュー
    @ViewBuilder
    private func menu(for entry: Entry) -> some View {
        Button("編集", systemImage: "pencil") { editing = entry }
        if entry.canFinish {
            Button("ここまで", systemImage: "stop.circle") { entry.finish() }
        }
        if entry.isImported {
            Button(entry.isHidden ? "表示" : "隠す",
                   systemImage: entry.isHidden ? "eye" : "eye.slash") { entry.isHidden.toggle() }
        } else {
            Button("削除", systemImage: "trash", role: .destructive) { context.delete(entry) }
        }
    }
}

struct EntryRow: View {
    let entry: Entry

    private static let timeFormat = Date.FormatStyle(date: .omitted, time: .shortened)
        .locale(Locale(identifier: "ja_JP"))

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(timeText)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
            Image(systemName: entry.kind.symbol)
                .foregroundStyle(.tint)
                .frame(width: 18)
            Text(entry.text)
                .strikethrough(entry.isHidden)
                .foregroundStyle(entry.isHidden ? .secondary : .primary)
        }
    }

    private var timeText: String {
        let start = entry.start.formatted(Self.timeFormat)
        guard let end = entry.end else { return start }
        return "\(start)–\(end.formatted(Self.timeFormat))"
    }
}

extension RecordKind {
    var symbol: String {
        switch self {
        case .memo: "pencil"
        case .wake: "sunrise"
        case .sleep: "moon.zzz"
        case .workout: "figure.outdoor.cycle"
        case .checkin: "mappin.and.ellipse"
        }
    }
}
