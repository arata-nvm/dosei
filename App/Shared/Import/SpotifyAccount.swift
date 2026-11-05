import CryptoKit
import DoseiCore
import Foundation

/// Spotify のログイン状態。
///
/// 更新用のトークン（refresh token）を iCloud キーチェーンに保存し、iPhone と Mac で共有する。
/// アクセストークンは1時間で切れるので、取り込みのたびに必要なら取り直す。
@MainActor
enum SpotifyAccount {
    private static let keychainAccount = "spotify-refresh-token"
    /// アクセストークンはこの端末のメモリにだけ持つ
    private static var cached: SpotifyAPI.Token?
    /// 更新中のトークン（同時に呼ばれても、更新は1回だけ送る）
    private static var refreshing: Task<SpotifyAPI.Token, Error>?

    /// 取ったお気に入りの曲を5分間覚えておく（昔の日を開くたびに全部取り直さないため）
    nonisolated static let library = SpotifyLibrary { url in
        try await SpotifyAPI.savedTracksPage(url, accessToken: try await SpotifyAccount.accessToken())
    }

    static var isLoggedIn: Bool { Keychain.get(keychainAccount) != nil }

    static var clientID: String {
        UserDefaults.standard.string(forKey: AppSettings.Key.spotifyClientID) ?? ""
    }

    static func logout() {
        Keychain.set(nil, for: keychainAccount)
        cached = nil
        Task { await library.reset() }
    }

    /// 使えるアクセストークン（切れていれば取り直す）
    static func accessToken() async throws -> String {
        if let cached, cached.isValid() { return cached.accessToken }
        if let refreshing { return try await refreshing.value.accessToken }
        guard let refreshToken = Keychain.get(keychainAccount) else { throw AccountError.notLoggedIn }
        let clientID = clientID
        let task = Task {
            // 待っている側が戻る前に結果を保存し、印を消す
            defer { refreshing = nil }
            let token = try await SpotifyAPI.refresh(refreshToken: refreshToken, clientID: clientID)
            save(token)
            return token
        }
        refreshing = task
        return try await task.value.accessToken
    }

    private static func save(_ token: SpotifyAPI.Token) {
        cached = token
        // 更新のたびに新しい refresh token が返ることがあるので、そのつど保存し直す
        if let refreshToken = token.refreshToken {
            Keychain.set(refreshToken, for: keychainAccount)
        }
    }

    // MARK: - ログイン（PKCE）

    /// ブラウザでのログインに使う値。authorizeURL を開き、戻ってきた URL を finish に渡す
    struct LoginRequest {
        let url: URL
        fileprivate let verifier: String
        fileprivate let state: String
    }

    static func makeLoginRequest() -> LoginRequest? {
        let verifier = randomString(length: 64)
        let state = randomString(length: 16)
        guard
            let url = SpotifyAPI.authorizeURL(
                clientID: clientID, codeChallenge: codeChallenge(for: verifier), state: state)
        else { return nil }
        return LoginRequest(url: url, verifier: verifier, state: state)
    }

    static func finish(_ request: LoginRequest, callback: URL) async throws {
        guard let code = SpotifyAPI.code(fromCallback: callback, expectedState: request.state) else {
            throw AccountError.loginFailed
        }
        save(try await SpotifyAPI.exchange(code: code, codeVerifier: request.verifier, clientID: clientID))
    }

    /// code_verifier の SHA-256 を base64url にしたもの
    private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomString(length: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    enum AccountError: LocalizedError {
        case notLoggedIn, loginFailed

        var errorDescription: String? {
            switch self {
            case .notLoggedIn: "Spotify にログインしていません"
            case .loginFailed: "ログインできませんでした"
            }
        }
    }
}

/// 取り込み元としての Spotify（お気に入りの曲）
struct SpotifySource: RecordSource {
    var name: String { "Spotify" }

    func records(for day: DiaryDay) async throws -> [ImportedRecord] {
        try await SpotifyAccount.library.tracks(from: day.startDate, to: day.endDate).map(\.record)
    }
}
