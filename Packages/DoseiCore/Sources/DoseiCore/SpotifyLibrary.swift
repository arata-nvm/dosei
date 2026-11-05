import Foundation

/// 取ってきたお気に入りの曲を、しばらくアプリの中に覚えておく。
///
/// Spotify は新しく追加した順にしか返さないので、昔の日を開くと、その日までの曲を全部取ることになる。
/// 日付をさかのぼるたびに最初から取り直すと Spotify に負担がかかるので、取った分は覚えておき、
/// 足りないときだけ続きのページを取る。新しく追加した曲を拾うため、maxAge を過ぎたら覚えた分を捨てる。
public actor SpotifyLibrary {
    public typealias FetchPage = @Sendable (URL) async throws -> SpotifyAPI.SavedTracksPage

    private let fetchPage: FetchPage
    private let maxAge: TimeInterval
    private let now: @Sendable () -> Date

    /// 新しい順
    private var tracks: [SpotifyAPI.SavedTrack] = []
    private var next: URL? = SpotifyAPI.savedTracksFirstPage
    private var fetchedAt: Date?
    /// 取っている途中のページ（同時に呼ばれても、同じページを2回取らない）
    private var loading: Task<Void, Error>?

    public init(
        maxAge: TimeInterval = 5 * 60, now: @escaping @Sendable () -> Date = { Date() },
        fetchPage: @escaping FetchPage
    ) {
        self.maxAge = maxAge
        self.now = now
        self.fetchPage = fetchPage
    }

    /// from 〜 to の間に追加した曲
    public func tracks(from: Date, to: Date) async throws -> [SpotifyAPI.SavedTrack] {
        if let fetchedAt, now().timeIntervalSince(fetchedAt) >= maxAge {
            reset()
        }
        // 覚えている中で一番古い曲が from より前になるまで（＝その日の分がそろうまで）続きを取る
        while !covers(from), next != nil {
            try await loadNextPage()
        }
        return tracks.filter { $0.addedAt >= from && $0.addedAt < to }
    }

    /// ログアウトしたときなど
    public func reset() {
        tracks = []
        next = SpotifyAPI.savedTracksFirstPage
        fetchedAt = nil
    }

    private func covers(_ date: Date) -> Bool {
        guard let oldest = tracks.last?.addedAt else { return false }
        return oldest < date
    }

    private func loadNextPage() async throws {
        if let loading {
            return try await loading.value
        }
        guard let url = next else { return }
        let task = Task {
            // 印は取得の中で消す。外で消すと、待っていた側が「終わった取得」を待ち直し続けて止まらなくなる
            defer { self.loading = nil }
            try await self.append(try await self.fetchPage(url))
        }
        loading = task
        try await task.value
    }

    private func append(_ page: SpotifyAPI.SavedTracksPage) {
        if fetchedAt == nil { fetchedAt = now() }
        tracks += page.tracks
        next = page.tracks.isEmpty ? nil : page.next
    }
}
