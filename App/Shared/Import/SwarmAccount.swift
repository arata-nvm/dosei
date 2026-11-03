import DoseiCore
import Foundation

/// Swarm のトークンの保存場所（iCloud キーチェーン。iPhone と Mac で共有される）
enum SwarmAccount {
    private static let keychainAccount = "swarm-token"

    static var token: String? {
        get { Keychain.get(keychainAccount) }
        set { Keychain.set(newValue, for: keychainAccount) }
    }

    /// ログインしていれば API
    static var api: SwarmAPI? {
        token.map(SwarmAPI.init(token:))
    }
}

extension SwarmAPI: RecordSource {
    var name: String { "Swarm" }

    func records(for day: DiaryDay) async throws -> [ImportedRecord] {
        try await checkins(from: day.startDate, to: day.endDate).map(\.record)
    }
}
