import Foundation
import HealthKit
import SwiftData
import DoseiCore

/// ヘルスケアに睡眠やワークアウトが増えたら、iOS にアプリを裏で起こしてもらって取り込む。
///
/// - 起動のたびに登録し直す必要がある（App の init と、許可が出た直後に呼ぶ）
/// - iPhone がロック中はヘルスケアのデータを読めないので、その場合は失敗して、
///   ロック解除後の次の通知か、アプリを開いたときに取り込まれる
@MainActor
enum HealthBackground {
    private static var started = false
    private static let authorizedKey = "healthAuthorizationRequested"

    static let types: [HKSampleType] = [
        HKCategoryType(.sleepAnalysis),
        HKObjectType.workoutType(),
    ]

    /// - Parameter afterAuthorization: 許可を求めた直後なら true。
    ///   まだ一度も許可を求めていないときに登録しても失敗するので、起動時は許可済みのときだけ登録する。
    static func start(afterAuthorization: Bool = false) {
        if afterAuthorization {
            UserDefaults.standard.set(true, forKey: authorizedKey)
        }
        guard !started,
              HealthImporter.isAvailable,
              UserDefaults.standard.bool(forKey: authorizedKey) else { return }
        started = true

        let store = HealthImporter.store
        for type in types {
            // 通知はメインスレッド以外で届くので、MainActor に縛られないよう @Sendable にする
            let query = HKObserverQuery(sampleType: type, predicate: nil) { @Sendable _, completionHandler, error in
                // completionHandler は必ず呼ぶ。呼ばないと iOS が配信を止めてしまう。
                guard error == nil else {
                    completionHandler()
                    return
                }
                Task { @MainActor in
                    await importRecent()
                    completionHandler()
                }
            }
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
    }

    /// 昨日と今日の分を取り込む（夜中の睡眠は昨日の「就寝」と今日の「起床」の両方に関わるため）
    static func importRecent() async {
        let context = SharedStore.container.mainContext
        let today = AppSettings.today
        for day in [today.adding(days: -1), today] {
            try? await Importer.importHealth(day, into: context)
        }
    }
}
