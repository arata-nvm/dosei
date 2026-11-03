import SwiftUI
import SwiftData

struct EntryEditor: View {
    @Bindable var entry: Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var start = Date()
    @State private var hasEnd = false
    @State private var end = Date()
    @State private var isHidden = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("やったこと", text: $text, axis: .vertical)
                DatePicker("時刻", selection: $start)
                Toggle("終わりの時刻（〜から〜まで）", isOn: $hasEnd)
                if hasEnd {
                    DatePicker("終わり", selection: $end, in: start...)
                }
                if entry.sourceID != nil {
                    Toggle("日記に載せない", isOn: $isHidden)
                    Text("取り込んだ記録です。ここで直した内容は、次に取り込んでも上書きされません。")
                        .font(.footnote).foregroundStyle(.secondary)
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
