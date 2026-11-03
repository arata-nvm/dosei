import Foundation
import SwiftData
import DoseiCore

/// 記録の取り込み元（Swarm、ヘルスケア）。その日の分を ImportedRecord で返すだけで、保存はしない。
protocol RecordSource {
    /// エラー表示に使う名前
    var name: String { get }
    func records(for day: DiaryDay) async throws -> [ImportedRecord]
}

/// 取り込み元から記録を取ってきて、Entry として保存する。
@MainActor
enum Importer {
    /// 画面から取り込むときの取り込み元（使えるものだけ）
    static var sources: [any RecordSource] {
        var sources: [any RecordSource] = []
        #if os(iOS)
        if HealthClient.isAvailable {
            sources.append(HealthSource(requestsAuthorization: true))
        }
        #endif
        if let swarm = SwarmAccount.api {
            sources.append(swarm)
        }
        return sources
    }

    /// 使える取り込み元すべてから取り込む
    @discardableResult
    static func importDay(_ day: DiaryDay, into context: ModelContext) async -> [String] {
        await importDay(day, from: sources, into: context)
    }

    /// - Returns: 表示するエラーメッセージ。キャンセルされただけのものは含めない。
    @discardableResult
    static func importDay(_ day: DiaryDay, from sources: [any RecordSource],
                          into context: ModelContext) async -> [String] {
        var errors: [String] = []
        for source in sources {
            do {
                save(try await source.records(for: day), into: context)
            } catch where !isCancellation(error) {
                errors.append("\(source.name): \(error.localizedDescription)")
            } catch {
                // 日付を切り替えて止められただけ
            }
        }
        try? context.save()
        return errors
    }

    /// sourceID で既存を探し、なければ追加、あれば更新する。
    /// iPhone と Mac で同時に取り込むと CloudKit 経由で重複しうるので、余分は消す。
    static func save(_ records: [ImportedRecord], into context: ModelContext) {
        for record in records {
            let sid: String? = record.sourceID
            let descriptor = FetchDescriptor<Entry>(
                predicate: #Predicate<Entry> { $0.sourceID == sid },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let existing = (try? context.fetch(descriptor)) ?? []
            if let first = existing.first {
                first.update(from: record)
                for duplicate in existing.dropFirst() {
                    context.delete(duplicate)
                }
            } else {
                context.insert(Entry(record))
            }
        }
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }
}
