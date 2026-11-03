import DoseiCore
import SwiftData
import SwiftUI

/// 1行の編集。保存するまで Entry には書き込まない。
struct EntryEditor: View {
    @Bindable var entry: Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var start = Date()
    @State private var hasEnd = false
    @State private var end = Date()
    @State private var isHidden = false
    /// この記録が入っている日記の日。編集では時刻だけを選び、日は動かさない。
    @State private var day = AppSettings.today

    var body: some View {
        NavigationStack {
            Form {
                // Form の中だと「左に項目名、右に入力欄」になり、文字が右にそろうので、
                // 項目名は出さずに行の幅いっぱいにして左にそろえる
                TextField("やったこと", text: $text, prompt: Text("やったこと"), axis: .vertical)
                    .labelsHidden()
                    .multilineTextAlignment(.leading)
                    // 折り返しはするが、改行は入れない
                    .onChange(of: text) { _, new in
                        if new.contains(where: \.isNewline) {
                            text = new.filter { !$0.isNewline }
                        }
                    }
                // 日付まで選べると、間違えて別の日（見えない明日など）に移ってしまうので時刻だけにする
                DatePicker("時刻", selection: timeInDay($start), displayedComponents: .hourAndMinute)
                Toggle("終了時刻", isOn: $hasEnd)
                if hasEnd {
                    DatePicker("終了", selection: timeInDay($end), displayedComponents: .hourAndMinute)
                }
                if entry.isImported {
                    Toggle("隠す", isOn: $isHidden)
                } else {
                    Button("削除", role: .destructive) {
                        context.delete(entry)
                        dismiss()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
        }
        .onAppear {
            day = DiaryDay(containing: entry.start, boundaryHour: AppSettings.boundaryHour)
            text = entry.text
            start = entry.start
            hasEnd = entry.end != nil
            end = entry.end ?? entry.start.addingTimeInterval(30 * 60)
            isHidden = entry.isHidden
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }

    /// 選んだ「時:分」を、この記録の日記の日の中の日時にする
    private func timeInDay(_ date: Binding<Date>) -> Binding<Date> {
        Binding(
            get: { date.wrappedValue },
            set: { picked in
                let c = DoseiFormatter.japaneseCalendar.dateComponents([.hour, .minute], from: picked)
                date.wrappedValue = day.date(
                    hour: c.hour ?? 0, minute: c.minute ?? 0, boundaryHour: AppSettings.boundaryHour)
            })
    }

    private func save() {
        entry.text = text
        entry.start = start
        entry.end = hasEnd ? max(end, start) : nil
        entry.isHidden = isHidden
        entry.userEdited = true
        try? context.save()
        dismiss()
    }
}
