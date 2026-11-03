import Foundation
import HealthKit
import DosekiCore

/// Apple Watch の睡眠とワークアウトをヘルスケアから読む（iPhone のみ）。
struct HealthImporter {
    static let store = HKHealthStore()

    struct Workout {
        var id: UUID
        var start: Date
        var end: Date
        var name: String
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static func requestAuthorization() async throws {
        try await store.requestAuthorization(
            toShare: [],
            read: [HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()]
        )
    }

    /// その日の起床・就寝時刻
    static func wakeAndBed(for day: DiaryDay) async throws -> (wake: Date?, bed: Date?) {
        // 前夜から寝ている分と、翌朝まで続く分も含めて取る
        let from = day.startDate.addingTimeInterval(-10 * 3600)
        let to = day.endDate.addingTimeInterval(4 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        let asleep = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let intervals = samples
            .filter { asleep.contains($0.value) }
            .map { DateInterval2(start: $0.startDate, end: $0.endDate) }
        let sessions = SleepAnalyzer.sessions(intervals)
        return SleepAnalyzer.wakeAndBed(sessions: sessions, day: day, boundaryHour: AppSettings.boundaryHour)
    }

    static func workouts(for day: DiaryDay) async throws -> [Workout] {
        let predicate = HKQuery.predicateForSamples(withStart: day.startDate, end: day.endDate, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let workouts = try await descriptor.result(for: store)
        return workouts.map {
            Workout(id: $0.uuid, start: $0.startDate, end: $0.endDate, name: name(of: $0.workoutActivityType))
        }
    }

    static func name(of type: HKWorkoutActivityType) -> String {
        switch type {
        case .cycling: "自転車"
        case .walking: "徒歩"
        case .running: "ランニング"
        case .hiking: "ハイキング"
        case .swimming: "水泳"
        case .yoga: "ヨガ"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "筋トレ"
        case .highIntensityIntervalTraining: "HIIT"
        case .dance: "ダンス"
        case .elliptical: "クロストレーナー"
        case .rowing: "ローイング"
        case .stairClimbing: "階段"
        case .tennis: "テニス"
        case .soccer: "サッカー"
        case .basketball: "バスケットボール"
        default: "運動"
        }
    }
}
