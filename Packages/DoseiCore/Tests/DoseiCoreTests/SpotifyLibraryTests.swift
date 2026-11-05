import Foundation
import XCTest

@testable import DoseiCore

/// 取ったページの数を数えるための、にせの Spotify
private final class FakeSpotify: @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URL] = []
    var requests: [URL] { lock.withLock { _requests } }

    /// 1ページ2曲。1時間ごとに1曲、now から過去へ並ぶ（新しい順）
    let pages: [SpotifyAPI.SavedTracksPage]

    init(now: Date, pageCount: Int) {
        pages = (0..<pageCount).map { p in
            let tracks = (0..<2).map { i -> SpotifyAPI.SavedTrack in
                let n = p * 2 + i
                return .init(
                    id: "t\(n)", name: "曲\(n)", artists: ["A"], addedAt: now.addingTimeInterval(-3600 * Double(n)))
            }
            let next = p + 1 < pageCount ? URL(string: "https://example.com/page\(p + 1)") : nil
            return .init(tracks: tracks, next: next)
        }
    }

    func fetch(_ url: URL) async throws -> SpotifyAPI.SavedTracksPage {
        lock.withLock { _requests.append(url) }
        if url == SpotifyAPI.savedTracksFirstPage { return pages[0] }
        let index = Int(url.lastPathComponent.dropFirst("page".count))!
        return pages[index]
    }
}

final class SpotifyLibraryTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000_000)
    func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-3600 * h) }

    func testFetchesOnlyWhatIsNeededAndReusesIt() async throws {
        let fake = FakeSpotify(now: now, pageCount: 10)
        let now = self.now
        let library = SpotifyLibrary(now: { now }, fetchPage: { try await fake.fetch($0) })

        // 直近3時間：1ページ目（0,1時間前）と2ページ目（2,3時間前）までで足りる
        let recent = try await library.tracks(from: hoursAgo(3.5), to: now.addingTimeInterval(1))
        XCTAssertEqual(recent.map(\.id), ["t0", "t1", "t2", "t3"])
        XCTAssertEqual(fake.requests.count, 3)  // 3.5時間前より古い曲（t4）が出るまで

        // もう少し前の日を開いても、足りない分だけ取る
        let older = try await library.tracks(from: hoursAgo(7.5), to: hoursAgo(5.5))
        XCTAssertEqual(older.map(\.id), ["t6", "t7"])
        XCTAssertEqual(fake.requests.count, 5)

        // 同じ範囲をもう一度開いても取り直さない
        _ = try await library.tracks(from: hoursAgo(3.5), to: now.addingTimeInterval(1))
        XCTAssertEqual(fake.requests.count, 5)
    }

    func testStopsAtTheEnd() async throws {
        let fake = FakeSpotify(now: now, pageCount: 2)
        let now = self.now
        let library = SpotifyLibrary(now: { now }, fetchPage: { try await fake.fetch($0) })
        let all = try await library.tracks(from: hoursAgo(1000), to: now.addingTimeInterval(1))
        XCTAssertEqual(all.count, 4)
        XCTAssertEqual(fake.requests.count, 2)  // 最後のページの先は取らない
        _ = try await library.tracks(from: hoursAgo(1000), to: now.addingTimeInterval(1))
        XCTAssertEqual(fake.requests.count, 2)
    }

    func testRefetchesAfterMaxAge() async throws {
        let fake = FakeSpotify(now: now, pageCount: 3)
        final class Clock: @unchecked Sendable { var now: Date; init(_ d: Date) { now = d } }
        let clock = Clock(now)
        let library = SpotifyLibrary(maxAge: 300, now: { clock.now }, fetchPage: { try await fake.fetch($0) })
        _ = try await library.tracks(from: hoursAgo(0.5), to: now.addingTimeInterval(1))
        XCTAssertEqual(fake.requests.count, 1)
        clock.now = now.addingTimeInterval(301)  // 5分過ぎたら、新しく追加された曲を拾うために取り直す
        _ = try await library.tracks(from: hoursAgo(0.5), to: now.addingTimeInterval(1))
        XCTAssertEqual(fake.requests.count, 2)
    }

    func testConcurrentCallsShareRequests() async throws {
        let fake = FakeSpotify(now: now, pageCount: 10)
        let now = self.now
        let library = SpotifyLibrary(now: { now }, fetchPage: { try await fake.fetch($0) })
        async let a = library.tracks(from: hoursAgo(5.5), to: now)
        async let b = library.tracks(from: hoursAgo(5.5), to: now)
        _ = try await (a, b)
        XCTAssertEqual(fake.requests.count, 4)  // 2回呼んでも、同じページは1回ずつ
        XCTAssertEqual(Set(fake.requests).count, 4)
    }
}
