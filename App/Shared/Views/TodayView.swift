import SwiftUI
import SwiftData
import DoseiCore

/// メイン画面。その日の記録の一覧と入力欄。左右のスワイプで日付を変える。
struct TodayView: View {
    @Environment(\.modelContext) private var context
    /// 起動した日を基準に、何日前を見ているか（0 = 今日、-1 = 昨日）
    @State private var baseDay = AppSettings.today
    @State private var offset = 0
    #if os(iOS)
    /// 横スクロールで見えているページ（offset と同じ数え方）
    @State private var visiblePage: Int? = 0
    #endif
    @State private var draft = ""
    @State private var importing = false
    @State private var importErrors: [String] = []
    @State private var editing: Entry?
    @State private var showSummary = false
    @State private var showSettings = false

    /// さかのぼれる日数
    private static let maxDaysBack = 3650

    private var day: DiaryDay { baseDay.adding(days: offset) }
    private var isToday: Bool { day == AppSettings.today }

    var body: some View {
        VStack(spacing: 0) {
            pages
            inputBar
        }
        .navigationTitle(day.title())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        .sheet(item: $editing) { EntryEditor(entry: $0) }
        .sheet(isPresented: $showSummary) { SummaryView(day: day) }
        #if os(iOS)
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
        #endif
        .alert("取り込めませんでした", isPresented: .constant(!importErrors.isEmpty)) {
            Button("OK") { importErrors = [] }
        } message: {
            Text(importErrors.joined(separator: "\n"))
        }
        .task(id: day) {
            // スワイプで日付を次々に変えている間は取り込まない
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await runImport()
        }
        .refreshable { await runImport() }
    }

    // MARK: - 日付のページ

    @ViewBuilder
    private var pages: some View {
        #if os(iOS)
        // 横スクロールをページ単位で止める。LazyHStack は見えているページしか作らないので、
        // 全日分を並べても重くならず、スクロール中に作り直しも起きない。
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(-Self.maxDaysBack...0, id: \.self) { i in
                    DayEntriesList(day: baseDay.adding(days: i), editing: $editing)
                        .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visiblePage)
        .defaultScrollAnchor(.trailing)   // 今日（右端）から始める
        .scrollIndicators(.hidden)
        .onChange(of: visiblePage) { _, page in
            if let page { offset = page }
        }
        #else
        DayEntriesList(day: day, editing: $editing)
            .onTrackpadSwipe(isEnabled: editing == nil && !showSummary) { direction in
                switch direction {
                case .right: goBack()
                case .left: goForward()
                }
            }
        #endif
    }

    private func goBack() {
        if offset > -Self.maxDaysBack { offset -= 1 }
    }

    private func goForward() {
        if offset < 0 { offset += 1 }
    }

    // MARK: - 入力欄

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("やったこと", text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
                .submitLabel(.done)
            Button(action: add) {
                Label("記録", systemImage: "arrow.up.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
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
        // 今日なら今の時刻。過去の日なら正午ごろに置いて、編集画面で直してもらう。
        let start = isToday ? Date() : day.startDate.addingTimeInterval(8 * 3600)
        let entry = Entry(start: start, text: text)
        context.insert(entry)
        try? context.save()
        draft = ""
        if !isToday { editing = entry }
    }

    private func runImport() async {
        importing = true
        let errors = await Importer.importDay(day, into: context)
        importing = false
        guard !Task.isCancelled else { return }
        importErrors = errors
    }

    // MARK: - ツールバー

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        #if os(macOS)
        // iPhone はスワイプで変えるので矢印を出さない（バーが狭く、日付が隠れるため）
        ToolbarItemGroup(placement: .navigation) {
            Button("前の日", systemImage: "chevron.left") { withAnimation { goBack() } }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(offset <= -Self.maxDaysBack)
            Button("次の日", systemImage: "chevron.right") { withAnimation { goForward() } }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(offset >= 0)
        }
        #endif
        ToolbarItemGroup(placement: .primaryAction) {
            #if os(macOS)
            // iPhone は下に引っぱって取り込む（バーが狭いので出さない）
            if importing {
                ProgressView().controlSize(.small)
            } else {
                Button("取り込む", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await runImport() }
                }
            }
            #endif
            Button("まとめる", systemImage: "doc.plaintext") { showSummary = true }
            #if os(iOS)
            Button("設定", systemImage: "gearshape") { showSettings = true }
            #endif
        }
    }
}
