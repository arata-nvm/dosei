import Foundation

/// Swarm（Foursquare API v2）から自分のチェックインを取ってくる。
struct SwarmClient {
    static let tokenAccount = "swarm-token"
    static let callbackScheme = "dosei"
    static let redirectURI = "dosei://swarm"

    struct Checkin {
        var id: String
        var date: Date
        var venue: String
        var shout: String?
    }

    var token: String

    static var saved: SwarmClient? {
        Keychain.get(tokenAccount).map { SwarmClient(token: $0) }
    }

    /// ブラウザで開く認可URL（token フロー。リダイレクト先の #access_token= を受け取る）
    static func authorizeURL(clientID: String) -> URL? {
        var c = URLComponents(string: "https://foursquare.com/oauth2/authenticate")!
        c.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "token"),
            .init(name: "redirect_uri", value: redirectURI),
        ]
        return c.url
    }

    static func token(fromCallback url: URL) -> String? {
        guard let fragment = url.fragment else { return nil }
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, kv[0] == "access_token" { return String(kv[1]) }
        }
        return nil
    }

    func checkins(from: Date, to: Date) async throws -> [Checkin] {
        var c = URLComponents(string: "https://api.foursquare.com/v2/users/self/checkins")!
        c.queryItems = [
            .init(name: "oauth_token", value: token),
            .init(name: "v", value: "20240101"),
            .init(name: "limit", value: "250"),
            .init(name: "sort", value: "oldestfirst"),
            .init(name: "afterTimestamp", value: String(Int(from.timeIntervalSince1970))),
            .init(name: "beforeTimestamp", value: String(Int(to.timeIntervalSince1970))),
        ]
        let (data, response) = try await URLSession.shared.data(from: c.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw SwarmError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.response.checkins.items.map {
            Checkin(
                id: $0.id,
                date: Date(timeIntervalSince1970: TimeInterval($0.createdAt)),
                venue: $0.venue?.name ?? "（場所不明）",
                shout: $0.shout
            )
        }
    }

    enum SwarmError: LocalizedError {
        case http(Int, String)
        var errorDescription: String? {
            switch self {
            case let .http(code, body): "Swarm API がエラーを返しました (\(code)): \(body.prefix(200))"
            }
        }
    }

    private struct Response: Decodable {
        struct Inner: Decodable { var checkins: Checkins }
        struct Checkins: Decodable { var items: [Item] }
        struct Item: Decodable {
            var id: String
            var createdAt: Int
            var shout: String?
            var venue: Venue?
        }
        struct Venue: Decodable { var name: String }
        var response: Inner
    }
}
