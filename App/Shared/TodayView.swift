import SwiftUI
import SwiftData
import DoseiCore

struct TodayView: View {
    @Environment(\.modelContext) private var context
    /// 起動した日を基準に、何日前を見ているか（0 = 今日、-1 = 昨日）
    @State private var baseDay: DiaryDay = AppSettings.today
    @State private var offset = 0
    @State private var draft = ""
    @State private var importing = false
    @State private var importMessages: [String] = []
    @State private var editing: Entry?
    @State private var showSummary = false
    @State private var showSettings = false
    @FocusState private var inputFocused: Bool

    private var day: DiaryDay { baseDay.adding(days: offset) }
    private var isToday: Bool { day == AppSettings.today }

    /// スワイプでさかのぼれる日数
    private static let maxDaysBack = 3650

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // 横スワイプで日付を変える
            TabView(selection: $offset) {
                ForEach(-Self.maxDaysBack...0, id: \.self) { i in
                    DayEntriesList(day: baseDay.adding(days: i), editing: $editing)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            DayEntriesList(day: day, editing: $editing)
            #endif
            inputBar
        }
        .navigationTitle(day.title())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        .sheet(item: $editing) { entry in
            EntryEditor(entry: entry)
        }
        .sheet(isPresented: $showSummary) {
            SummaryView(day: day)
        }
        #if os(iOS)
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        #endif
        .alert("取り込みでエラー", isPresented: .constant(!importMessages.isEmpty)) {
            Button("OK") { importMessages = [] }
        } message: {
            Text(importMessages.joined(separator: "\n"))
        }
        .task(id: day) { await runImport() }
        .refreshable { await runImport() }
    }

    // MARK: - 入力欄

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(isToday ? "いま何してる？" : "この日に追加（時刻はあとで直せます）", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .onSubmit(add)
                .submitLabel(.done)
            Button(action: add) {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(12)
        .background(.bar)
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // 今日なら今の時刻。過去の日なら正午に置いて、編集画面で直してもらう。
        let start = isToday ? Date() : day.startDate.addingTimeInterval(8 * 3600)
        let entry = Entry(start: start, text: text)
        context.insert(entry)
        try? context.save()
        draft = ""
        if !isToday { editing = entry }
    }

    private func runImport() async {
        importing = true
        let report = await Importer.importDay(day, into: context)
        importing = false
        importMessages = report.messages
    }

    // MARK: - ツールバー

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { withAnimation { offset -= 1 } } label: { Image(systemName: "chevron.left") }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(offset <= -Self.maxDaysBack)
            Button { withAnimation { offset += 1 } } label: { Image(systemName: "chevron.right") }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(offset >= 0)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if importing {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await runImport() } } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .help("Swarm とヘルスケアから取り込む")
            }
            Button { showSummary = true } label: { Image(systemName: "doc.plaintext") }
                .help("首相動静風にまとめる")
            #if os(iOS)
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
            #endif
        }
    }
}

/// その日の Entry 一覧。@Query の条件に日付を入れるため別 View にしている。
struct DayEntriesList: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    @Binding var editing: Entry?

    init(day: DiaryDay, editing: Binding<Entry?>) {
        let from = day.startDate, to = day.endDate
        _entries = Query(
            filter: #Predicate<Entry> { $0.start >= from && $0.start < to },
            sort: \Entry.start
        )
        _editing = editing
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("まだ何もありません", systemImage: "clock",
                                       description: Text("下の欄にやったことを書くと、いまの時刻で記録されます"))
            }
            ForEach(entries) { entry in
                EntryRow(entry: entry)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = entry }
                    #if os(macOS)
                    // iPhone では横スワイプを日付の切り替えに使うので、行のスワイプは Mac だけ
                    .swipeActions(edge: .leading) {
                        if canEnd(entry) {
                            Button("ここまで") { end(entry) }
                                .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if entry.sourceID == nil {
                            Button("削除", role: .destructive) { context.delete(entry) }
                        } else {
                            // 取り込んだものは消すと次の取り込みで復活するので、隠す
                            Button(entry.isHidden ? "表示" : "隠す") { entry.isHidden.toggle() }
                                .tint(.gray)
                        }
                    }
                    #endif
                    .contextMenu {
                        Button("編集") { editing = entry }
                        if canEnd(entry) {
                            Button("ここまで（いまの時刻で終わり）") { end(entry) }
                        }
                        if entry.sourceID == nil {
                            Button("削除", role: .destructive) { context.delete(entry) }
                        } else {
                            Button(entry.isHidden ? "日記に載せる" : "日記に載せない") { entry.isHidden.toggle() }
                        }
                    }
            }
        }
    }

    private func canEnd(_ entry: Entry) -> Bool {
        entry.end == nil && entry.kind == .memo
    }

    private func end(_ entry: Entry) {
        entry.end = max(Date(), entry.start)
        entry.userEdited = true
    }
}

struct EntryRow: View {
    let entry: Entry

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
        let f = Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "ja_JP"))
        if let end = entry.end {
            return "\(entry.start.formatted(f))–\(end.formatted(f))"
        }
        return entry.start.formatted(f)
    }
}
