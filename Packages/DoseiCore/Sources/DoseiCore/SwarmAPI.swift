import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Swarm（Foursquare API v2）。トークンの保存場所は知らない（アプリ側が渡す）。
public struct SwarmAPI: Sendable {
    public static let callbackScheme = "dosei"
    public static let redirectURI = "dosei://swarm"

    public struct Checkin: Equatable, Sendable {
        public var id: String
        public var date: Date
        public var venue: String

        public var record: ImportedRecord {
            // 着いたとき・途中・出るときのどれでもチェックインするので、「着」「発」は付けない
            ImportedRecord(sourceID: SourceID.swarm(id), kind: .checkin, start: date, text: venue)
        }
    }

    public enum APIError: LocalizedError {
        case http(Int)

        public var errorDescription: String? {
            switch self {
            case .http(let code): "Swarm に接続できませんでした（\(code)）"
            }
        }
    }

    public var token: String

    public init(token: String) {
        self.token = token
    }

    // MARK: - ログイン

    /// ブラウザで開く認可URL（token フロー。リダイレクト先の #access_token= を受け取る）
    public static func authorizeURL(clientID: String) -> URL? {
        var c = URLComponents(string: "https://foursquare.com/oauth2/authenticate")!
        c.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "token"),
            .init(name: "redirect_uri", value: redirectURI),
        ]
        return c.url
    }

    public static func token(fromCallback url: URL) -> String? {
        guard let fragment = url.fragment else { return nil }
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, kv[0] == "access_token" { return String(kv[1]) }
        }
        return nil
    }

    // MARK: - チェックイン

    public func checkins(from: Date, to: Date) async throws -> [Checkin] {
        let (data, response) = try await URLSession.shared.data(from: checkinsURL(from: from, to: to))
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.http(http.statusCode)
        }
        return try Self.decodeCheckins(data)
    }

    func checkinsURL(from: Date, to: Date) -> URL {
        var c = URLComponents(string: "https://api.foursquare.com/v2/users/self/checkins")!
        c.queryItems = [
            .init(name: "oauth_token", value: token),
            .init(name: "v", value: "20240101"),
            .init(name: "limit", value: "250"),
            .init(name: "sort", value: "oldestfirst"),
            .init(name: "afterTimestamp", value: String(Int(from.timeIntervalSince1970))),
            .init(name: "beforeTimestamp", value: String(Int(to.timeIntervalSince1970))),
        ]
        return c.url!
    }

    static func decodeCheckins(_ data: Data) throws -> [Checkin] {
        try JSONDecoder().decode(Response.self, from: data).response.checkins.items.map {
            Checkin(
                id: $0.id,
                date: Date(timeIntervalSince1970: TimeInterval($0.createdAt)),
                venue: $0.venue?.name ?? "（場所不明）"
            )
        }
    }

    private struct Response: Decodable {
        struct Inner: Decodable { var checkins: Checkins }
        struct Checkins: Decodable { var items: [Item] }
        struct Item: Decodable {
            var id: String
            var createdAt: Int
            var venue: Venue?
        }
        struct Venue: Decodable { var name: String }
        var response: Inner
    }
}
