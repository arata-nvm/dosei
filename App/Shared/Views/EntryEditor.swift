import DoseiCore
import SwiftData
import SwiftUI

/// 1行の編集。保存するまで Entry には書き込まない。
struct EntryEditor: View {
    @Bindable var entry: Entry
    /// 保存したあとに呼ぶ（入る日記の日が変わったら、そのページに移るため）
    var onSave: @MainActor (Entry) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var start = Date()
    @State private var hasEnd = false
    @State private var end = Date()
    @State private var isHidden = false

    private var calendar: Calendar { DoseiFormatter.diaryCalendar }

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
                // 日付と時刻は別の欄にする（一緒だと、時刻を直すつもりで日付まで動いてしまう）。
                // どちらも暦の上の日時。どの日の日記に入るかは、日付の区切りの設定で決まる。
                DatePicker("日付", selection: startDate, displayedComponents: .date)
                DatePicker("時刻", selection: startTime, displayedComponents: .hourAndMinute)
                if let diaryDayNote {
                    Text(diaryDayNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Toggle("終了時刻", isOn: $hasEnd)
                if hasEnd {
                    DatePicker("終了", selection: endTime, displayedComponents: .hourAndMinute)
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

    /// 開始の日付。変えても時刻はそのまま
    private var startDate: Binding<Date> {
        Binding(
            get: { start },
            set: { setStart(combining(dayOf: $0, timeOf: start)) })
    }

    /// 開始の時刻。変えても日付はそのまま
    private var startTime: Binding<Date> {
        Binding(
            get: { start },
            set: { setStart(combining(dayOf: start, timeOf: $0)) })
    }

    /// 終了の時刻。開始より前の時刻なら、日付をまたいだ翌日の時刻とみなす
    private var endTime: Binding<Date> {
        Binding(
            get: { end },
            set: { end = endAfterStart(timeOf: $0) })
    }

    /// 開始を変えたら、終了も同じ時刻のまま開始の後ろに付いてくる
    private func setStart(_ date: Date) {
        start = date
        end = endAfterStart(timeOf: end)
    }

    private func combining(dayOf day: Date, timeOf time: Date) -> Date {
        let d = calendar.dateComponents([.year, .month, .day], from: day)
        let t = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            from: DateComponents(year: d.year, month: d.month, day: d.day, hour: t.hour, minute: t.minute)) ?? day
    }

    private func endAfterStart(timeOf time: Date) -> Date {
        let sameDay = combining(dayOf: start, timeOf: time)
        guard sameDay < start else { return sameDay }
        return calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay
    }

    /// 日付の区切りより前（深夜）のときだけ、どの日の日記に入るかを書く
    private var diaryDayNote: String? {
        let day = DiaryDay(containing: start, boundaryHour: AppSettings.boundaryHour)
        guard day != DiaryDay(calendarDayOf: start) else { return nil }
        return "日付の区切りより前なので、\(day.title())の日記に入ります"
    }

    private func save() {
        entry.text = text
        entry.start = start
        entry.end = hasEnd ? max(end, start) : nil
        entry.isHidden = isHidden
        entry.userEdited = true
        try? context.save()
        onSave(entry)
        dismiss()
    }
}
