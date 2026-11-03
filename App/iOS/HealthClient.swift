import Foundation
import HealthKit
import DoseiCore

/// Apple Watch の睡眠とワークアウトをヘルスケアから読む（iPhone のみ）。
enum HealthClient {
    static let store = HKHealthStore()

    /// 読む種類。許可の要求とバックグラウンド配信の両方で使う。
    static let readTypes: [HKSampleType] = [
        HKCategoryType(.sleepAnalysis),
        HKObjectType.workoutType(),
    ]

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: Set(readTypes.map { $0 as HKObjectType }))
    }

    /// その日の起床・就寝・ワークアウト
    static func records(for day: DiaryDay) async throws -> [ImportedRecord] {
        let sleep = try await wakeAndBed(for: day)
        let workoutRecords = try await workouts(for: day)
        return ImportedRecord.sleep(wake: sleep.wake, bed: sleep.bed, day: day) + workoutRecords
    }

    // MARK: - 睡眠

    private static func wakeAndBed(for day: DiaryDay) async throws -> (wake: Date?, bed: Date?) {
        // 前夜から寝ている分と、翌朝まで続く分も含めて取る
        let from = day.startDate.addingTimeInterval(-10 * 3600)
        let to = day.endDate.addingTimeInterval(4 * 3600)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(
                type: HKCategoryType(.sleepAnalysis),
                predicate: HKQuery.predicateForSamples(withStart: from, end: to)
            )],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let asleep = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let spans = try await descriptor.result(for: store)
            .filter { asleep.contains($0.value) }
            .map { TimeSpan(start: $0.startDate, end: $0.endDate) }
        return SleepAnalyzer.wakeAndBed(
            sessions: SleepAnalyzer.sessions(spans), day: day, boundaryHour: AppSettings.boundaryHour
        )
    }

    // MARK: - ワークアウト

    private static func workouts(for day: DiaryDay) async throws -> [ImportedRecord] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(
                withStart: day.startDate, end: day.endDate, options: .strictStartDate
            ))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: store).map {
            ImportedRecord(sourceID: SourceID.workout($0.uuid), kind: .workout,
                           start: $0.startDate, end: $0.endDate, text: name(of: $0.workoutActivityType))
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

/// 取り込み元としてのヘルスケア
struct HealthSource: RecordSource {
    /// 画面から取り込むときは true（許可を求める）。バックグラウンドでは false。
    var requestsAuthorization: Bool

    var name: String { "ヘルスケア" }

    func records(for day: DiaryDay) async throws -> [ImportedRecord] {
        if requestsAuthorization {
            try await HealthClient.requestAuthorization()
            await HealthBackground.start(afterAuthorization: true)
        }
        return try await HealthClient.records(for: day)
    }
}
