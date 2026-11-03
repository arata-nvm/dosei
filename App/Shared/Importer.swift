import Foundation
import SwiftData
import DoseiCore

/// Swarm とヘルスケアの記録を、その日の Entry として取り込む。
@MainActor
enum Importer {
    struct Report {
        var messages: [String] = []
    }

    static func importDay(_ day: DiaryDay, into context: ModelContext) async -> Report {
        var report = Report()

        #if os(iOS)
        if HealthImporter.isAvailable {
            do {
                try await HealthImporter.requestAuthorization()
                let sleep = try await HealthImporter.wakeAndBed(for: day)
                if let wake = sleep.wake {
                    upsert(context, sourceID: "hk-wake-\(day.key)", kind: .wake, start: wake, text: "起床")
                }
                if let bed = sleep.bed {
                    upsert(context, sourceID: "hk-bed-\(day.key)", kind: .sleep, start: bed, text: "就寝")
                }
                for w in try await HealthImporter.workouts(for: day) {
                    upsert(context, sourceID: "hk-workout-\(w.id.uuidString)", kind: .workout,
                           start: w.start, end: w.end, text: w.name)
                }
            } catch {
                report.messages.append("ヘルスケア: \(error.localizedDescription)")
            }
        }
        #endif

        if let swarm = SwarmClient.saved {
            do {
                for c in try await swarm.checkins(from: day.startDate, to: day.endDate) {
                    upsert(context, sourceID: "swarm-\(c.id)", kind: .checkin, start: c.date, text: "\(c.venue)着")
                }
            } catch {
                report.messages.append("Swarm: \(error.localizedDescription)")
            }
        }

        try? context.save()
        return report
    }

    /// sourceID で既存を探し、なければ追加、あれば（手で直していなければ）更新する。
    /// iPhone と Mac で同時に取り込むと CloudKit 経由で重複しうるので、余分は消す。
    static func upsert(_ context: ModelContext, sourceID: String, kind: Entry.Kind,
                       start: Date, end: Date? = nil, text: String) {
        let sid: String? = sourceID
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { $0.sourceID == sid },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let existing = (try? context.fetch(descriptor)) ?? []

        guard let first = existing.first else {
            context.insert(Entry(start: start, end: end, text: text, kind: kind, sourceID: sourceID))
            return
        }
        for extra in existing.dropFirst() {
            context.delete(extra)
        }
        if !first.userEdited {
            first.start = start
            first.end = end
            first.text = text
        }
    }
}
