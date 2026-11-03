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

    var body: some View {
        NavigationStack {
            Form {
                TextField("やったこと", text: $text, axis: .vertical)
                    // 折り返しはするが、改行は入れない
                    .onChange(of: text) { _, new in
                        if new.contains(where: \.isNewline) {
                            text = new.filter { !$0.isNewline }
                        }
                    }
                DatePicker("時刻", selection: $start)
                Toggle("終了時刻", isOn: $hasEnd)
                if hasEnd {
                    DatePicker("終了", selection: $end, in: start...)
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
