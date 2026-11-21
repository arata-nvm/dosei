import DoseiCore
import Foundation
import SwiftData

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
        if SpotifyAccount.isLoggedIn {
            sources.append(SpotifySource())
        }
        return sources
    }

    /// 自動で取り込んだ日と時刻。同じ日を何度開いても、そのたびに外部のサービスへ問い合わせないため
    private static var lastAutoImport: [DiaryDay: Date] = [:]
    private static let autoImportInterval: TimeInterval = 5 * 60

    /// 使える取り込み元すべてから取り込む
    /// - Parameter force: false（日付を開いたときの自動の取り込み）なら、同じ日を5分以内には取り込み直さない。
    ///   引っぱったときやボタンを押したときは true。
    @discardableResult
    static func importDay(_ day: DiaryDay, into context: ModelContext, force: Bool) async -> [String] {
        if !force, let last = lastAutoImport[day], Date().timeIntervalSince(last) < autoImportInterval {
            return []
        }
        let failures = await importFailures(day, from: sources, into: context)
        // 途中で止められたときや失敗したときは、次に開いたときにもう一度取り込む
        if !Task.isCancelled && failures.isEmpty {
            lastAutoImport[day] = Date()
        }
        // 自動の取り込みでは、つながらないだけのエラーは出さない。
        // オフラインで日付を変えるたびにアラートが出ないように。引っぱったときは出す。
        return failures.filter { force || !isOffline($0.error) }.map(\.message)
    }

    /// - Returns: 表示するエラーメッセージ。キャンセルされただけのものは含めない。
    @discardableResult
    static func importDay(
        _ day: DiaryDay, from sources: [any RecordSource],
        into context: ModelContext
    ) async -> [String] {
        await importFailures(day, from: sources, into: context).map(\.message)
    }

    private struct Failure {
        let error: Error
        let message: String
    }

    /// キャンセルされただけのものは含めない。
    private static func importFailures(
        _ day: DiaryDay, from sources: [any RecordSource],
        into context: ModelContext
    ) async -> [Failure] {
        var failures: [Failure] = []
        for source in sources {
            do {
                save(try await source.records(for: day), into: context)
            } catch {
                // 日付を切り替えて止められただけなら出さない
                if !isCancellation(error) {
                    failures.append(
                        Failure(error: error, message: "\(source.name): \(error.localizedDescription)"))
                }
            }
        }
        try? context.save()
        return failures
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

    /// ネットワークにつながらない（オフライン・機内モード・サーバーに届かない）ことによるエラーか
    static func isOffline(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return false }
        return [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDataNotAllowed,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorDNSLookupFailed,
            NSURLErrorTimedOut,
        ].contains(ns.code)
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }
}
