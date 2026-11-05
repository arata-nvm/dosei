import XCTest

@testable import DoseiCore

final class SpotifyTests: XCTestCase {
    func testDecodeSavedTracks() throws {
        let json = """
            {"items":[
              {"added_at":"2026-11-03T06:10:00Z","track":{"id":"3dPQuX8Gs42Y7b454ybpMR","name":"夜に駆ける",
                "artists":[{"name":"YOASOBI"}]}},
              {"added_at":"2026-11-03T02:00:00Z","track":{"id":"7ouMYWpwJ422jRcDASZB7P","name":"Duet",
                "artists":[{"name":"A"},{"name":"B"}]}},
              {"added_at":"2026-11-02T23:00:00Z","track":{"id":null,"name":"ローカルの曲","artists":[]}}
            ],"next":"https://api.spotify.com/v1/me/tracks?offset=50&limit=50"}
            """
        let page = try SpotifyAPI.decodeSavedTracks(Data(json.utf8))
        XCTAssertEqual(page.tracks.count, 2)  // id のない曲は飛ばす
        XCTAssertEqual(page.next?.absoluteString, "https://api.spotify.com/v1/me/tracks?offset=50&limit=50")

        let added = ISO8601DateFormatter().date(from: "2026-11-03T06:10:00Z")!
        XCTAssertEqual(
            page.tracks[0].record,
            ImportedRecord(
                sourceID: "spotify-3dPQuX8Gs42Y7b454ybpMR-\(Int(added.timeIntervalSince1970))",
                kind: .music, start: added, text: "YOASOBI『夜に駆ける』"))
        XCTAssertEqual(page.tracks[1].record.text, "A、B『Duet』")
    }

    func testLinkFromSourceID() {
        let id = SourceID.spotify(trackID: "3dPQuX8Gs42Y7b454ybpMR", addedAt: Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(id, "spotify-3dPQuX8Gs42Y7b454ybpMR-1000")
        XCTAssertEqual(SourceID.link(for: id), "https://open.spotify.com/track/3dPQuX8Gs42Y7b454ybpMR")
        XCTAssertNil(SourceID.link(for: "swarm-abc"))
        XCTAssertNil(SourceID.link(for: nil))
    }

    /// 曲のリンクは本文の下に、本文に出てくる順で段落を分けて並べる
    func testLinksAfterBody() {
        let cal = DoseiFormatter.japaneseCalendar
        let t = { (h: Int, m: Int) in cal.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: h, minute: m))!
        }
        let items: [TimelineItem] = [
            .init(start: t(15, 10), text: "YOASOBI『夜に駆ける』", link: "https://open.spotify.com/track/B"),
            .init(start: t(9, 0), text: "起床"),
            .init(start: t(12, 0), text: "A『X』", link: "https://open.spotify.com/track/A"),
        ]
        XCTAssertEqual(
            DoseiFormatter().format(items),
            "\u{3000}午前９時、起床。午後０時、A『X』。同３時１０分、YOASOBI『夜に駆ける』。"
                + "\n\nhttps://open.spotify.com/track/A"
                + "\n\nhttps://open.spotify.com/track/B")
    }

    func testAuthorizeURLAndCallback() {
        let url = SpotifyAPI.authorizeURL(clientID: "CID", codeChallenge: "CH", state: "S")!
        let q = Dictionary(
            uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map {
                ($0.name, $0.value!)
            })
        XCTAssertEqual(q["response_type"], "code")
        XCTAssertEqual(q["redirect_uri"], "dosei://spotify")
        XCTAssertEqual(q["code_challenge_method"], "S256")
        XCTAssertEqual(q["scope"], "user-library-read")

        XCTAssertEqual(
            SpotifyAPI.code(fromCallback: URL(string: "dosei://spotify?code=C&state=S")!, expectedState: "S"), "C")
        XCTAssertNil(SpotifyAPI.code(fromCallback: URL(string: "dosei://spotify?code=C&state=X")!, expectedState: "S"))
        XCTAssertNil(
            SpotifyAPI.code(
                fromCallback: URL(string: "dosei://spotify?error=access_denied&state=S")!, expectedState: "S"))
    }

    func testTokenRequestAndDecode() throws {
        let request = SpotifyAPI.tokenRequest([
            "grant_type": "refresh_token", "refresh_token": "R+/=", "client_id": "C",
        ])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            String(data: request.httpBody!, encoding: .utf8),
            "client_id=C&grant_type=refresh_token&refresh_token=R%2B/%3D")

        let now = Date(timeIntervalSince1970: 0)
        let token = try SpotifyAPI.decodeToken(
            Data(#"{"access_token":"A","token_type":"Bearer","expires_in":3600,"refresh_token":"R"}"#.utf8), now: now)
        XCTAssertEqual(token, .init(accessToken: "A", refreshToken: "R", expiresAt: Date(timeIntervalSince1970: 3600)))
        XCTAssertTrue(token.isValid(at: Date(timeIntervalSince1970: 3000)))
        XCTAssertFalse(token.isValid(at: Date(timeIntervalSince1970: 3550)))
    }
}
