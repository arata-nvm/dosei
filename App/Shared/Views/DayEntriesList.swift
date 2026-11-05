import DoseiCore
import SwiftData
import SwiftUI

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
        List {
            ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                EntryRow(entry: entry, isFirst: index == 0, isLast: index == entries.count - 1)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = entry }
                    .contextMenu { menu(for: entry) }
                    // 縦の線を行の間で途切れさせないため、上下の余白は行の中で取る
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
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
            Button(
                entry.isHidden ? "表示" : "隠す",
                systemImage: entry.isHidden ? "eye" : "eye.slash"
            ) { entry.isHidden.toggle() }
        } else {
            Button("削除", systemImage: "trash", role: .destructive) { context.delete(entry) }
        }
    }
}

/// 1行。左に縦の線とアイコン、右に「時刻（小さく）」「内容（幅いっぱい）」の2段。
struct EntryRow: View {
    let entry: Entry
    var isFirst = false
    var isLast = false

    /// 線とアイコンの欄の幅（文字の大きさの設定に合わせて変わる）
    @ScaledMetric(relativeTo: .body) private var railWidth = 28
    /// 行の上下の余白
    @ScaledMetric(relativeTo: .body) private var padding = 10

    private static let timeFormat = Date.FormatStyle(date: .omitted, time: .shortened)
        .locale(Locale(identifier: "ja_JP"))

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 線は下の overlay で行の高さいっぱいに描く。ここは幅を取るだけ
            Color.clear.frame(width: railWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(entry.text)
                    .strikethrough(entry.isHidden)
                    .foregroundStyle(entry.isHidden ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, padding)
        }
        .overlay(alignment: .leading) { rail }
    }

    /// 縦の線とアイコン。最初の行は上、最後の行は下の線を消す
    private var rail: some View {
        VStack(spacing: 0) {
            line.frame(height: padding - 4).opacity(isFirst ? 0 : 1)
            Image(systemName: entry.kind.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.isHidden ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(width: railWidth, height: railWidth)
                .background(Circle().fill(.background.secondary))
            line.opacity(isLast ? 0 : 1)
        }
        .frame(width: railWidth)
    }

    private var line: some View {
        Rectangle()
            .fill(.secondary.opacity(0.4))
            .frame(width: 2)
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
        case .music: "music.note"
        }
    }
}
