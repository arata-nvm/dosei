import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Spotify Web API。お気に入りの曲（Liked Songs）を、追加した時刻つきで取る。
///
/// ログインは PKCE（Client Secret を使わない方式）。トークンの保存場所は知らない（アプリ側が持つ）。
public enum SpotifyAPI {
    public static let redirectURI = "dosei://spotify"
    public static let scope = "user-library-read"

    // MARK: - ログイン

    /// ブラウザで開く認可 URL
    /// - Parameter codeChallenge: code_verifier の SHA-256 を base64url にしたもの（アプリ側で作る）
    public static func authorizeURL(clientID: String, codeChallenge: String, state: String) -> URL? {
        var c = URLComponents(string: "https://accounts.spotify.com/authorize")!
        c.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: codeChallenge),
            .init(name: "state", value: state),
        ]
        return c.url
    }

    /// リダイレクト先の ?code=...&state=... から code を取り出す（state が違えば nil）
    public static func code(fromCallback url: URL, expectedState: String) -> String? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == expectedState else { return nil }
        return items.first(where: { $0.name == "code" })?.value
    }

    // MARK: - トークン

    public struct Token: Equatable, Sendable {
        public var accessToken: String
        /// 更新のときに新しいものが返らなければ、前のものを使い続ける
        public var refreshToken: String?
        public var expiresAt: Date

        public init(accessToken: String, refreshToken: String?, expiresAt: Date) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.expiresAt = expiresAt
        }

        /// 期限の1分前からは切れたものとして扱う
        public func isValid(at now: Date = .now) -> Bool { now < expiresAt.addingTimeInterval(-60) }
    }

    /// ログイン直後：code をトークンに換える
    public static func exchange(code: String, codeVerifier: String, clientID: String) async throws -> Token {
        try await requestToken([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": codeVerifier,
        ])
    }

    /// アクセストークンは1時間で切れるので、更新用のトークンで取り直す
    public static func refresh(refreshToken: String, clientID: String) async throws -> Token {
        var token = try await requestToken([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])
        token.refreshToken = token.refreshToken ?? refreshToken
        return token
    }

    static func tokenRequest(_ form: [String: String]) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var c = URLComponents()
        c.queryItems = form.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        // フォームでは「+」が空白として読まれるので、そのまま送らない
        let body = (c.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
        request.httpBody = Data(body.utf8)
        return request
    }

    private static func requestToken(_ form: [String: String]) async throws -> Token {
        let (data, response) = try await URLSession.shared.data(for: tokenRequest(form))
        try check(response)
        return try decodeToken(data)
    }

    static func decodeToken(_ data: Data, now: Date = .now) throws -> Token {
        struct Response: Decodable {
            var accessToken: String
            var refreshToken: String?
            var expiresIn: Int
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in"
            }
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        return Token(
            accessToken: r.accessToken, refreshToken: r.refreshToken,
            expiresAt: now.addingTimeInterval(TimeInterval(r.expiresIn)))
    }

    // MARK: - お気に入りの曲

    public struct SavedTrack: Equatable, Sendable {
        public var id: String
        public var name: String
        public var artists: [String]
        public var addedAt: Date

        /// 「YOASOBI『夜に駆ける』」
        public var record: ImportedRecord {
            ImportedRecord(
                sourceID: SourceID.spotify(trackID: id, addedAt: addedAt), kind: .music, start: addedAt,
                text: "\(artists.joined(separator: "、"))『\(name)』")
        }
    }

    /// お気に入りの曲の最初のページ（新しい順に50曲）
    public static let savedTracksFirstPage = URL(string: "https://api.spotify.com/v1/me/tracks?limit=50")!

    /// お気に入りの曲を1ページ取る。続きのページの URL も返る
    public static func savedTracksPage(_ url: URL, accessToken: String) async throws -> SavedTracksPage {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        return try decodeSavedTracks(data)
    }

    public struct SavedTracksPage: Sendable {
        public var tracks: [SavedTrack]
        public var next: URL?

        public init(tracks: [SavedTrack], next: URL?) {
            self.tracks = tracks
            self.next = next
        }
    }

    static func decodeSavedTracks(_ data: Data) throws -> SavedTracksPage {
        struct Response: Decodable {
            struct Item: Decodable {
                struct Track: Decodable {
                    struct Artist: Decodable { var name: String }
                    var id: String?
                    var name: String
                    var artists: [Artist]
                }
                var addedAt: String
                var track: Track
                enum CodingKeys: String, CodingKey { case addedAt = "added_at", track }
            }
            var items: [Item]
            var next: String?
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        let iso = ISO8601DateFormatter()
        let tracks = r.items.compactMap { item -> SavedTrack? in
            // ローカルファイルの曲などは id がない
            guard let id = item.track.id, let date = iso.date(from: item.addedAt) else { return nil }
            return SavedTrack(id: id, name: item.track.name, artists: item.track.artists.map(\.name), addedAt: date)
        }
        return SavedTracksPage(tracks: tracks, next: r.next.flatMap(URL.init(string:)))
    }

    // MARK: -

    public enum APIError: LocalizedError {
        case http(Int)

        public var errorDescription: String? {
            switch self {
            case .http(let code): "Spotify に接続できませんでした（\(code)）"
            }
        }
    }

    private static func check(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
    }
}
