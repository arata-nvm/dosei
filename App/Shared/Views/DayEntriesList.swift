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
        // 一覧を下にスクロールするとキーボードが閉じる（メッセージと同じ）
        .scrollDismissesKeyboard(.interactively)
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

    /// アイコンの欄の幅（文字の大きさの設定に合わせて変わる）
    @ScaledMetric(relativeTo: .body) private var iconWidth = 24

    private static let timeFormat = Date.FormatStyle(date: .omitted, time: .shortened)
        .locale(Locale(identifier: "ja_JP"))

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            time
            Image(systemName: entry.kind.symbol)
                .foregroundStyle(.tint)
                .frame(width: iconWidth)
            Text(entry.text)
                .strikethrough(entry.isHidden)
                .foregroundStyle(entry.isHidden ? .secondary : .primary)
                .multilineTextAlignment(.leading)
        }
        // Mac の一覧では中央にそろうので、左にそろえる
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 時刻の欄。見えない「00:00」と重ねて、どの行も同じ幅にそろえる（文字の大きさを変えても崩れない）。
    /// 終了時刻は開始時刻の下に小さく出す。
    private var time: some View {
        ZStack(alignment: .topTrailing) {
            Text("00:00").hidden()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.start.formatted(Self.timeFormat))
                if let end = entry.end {
                    Text("–" + end.formatted(Self.timeFormat))
                        .font(.caption.monospacedDigit())
                }
            }
        }
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
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
