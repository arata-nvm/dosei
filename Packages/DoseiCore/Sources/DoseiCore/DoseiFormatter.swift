import Foundation

/// 日記の1行分。end があれば「〜から〜まで、」の形になる。
public struct TimelineItem: Equatable, Sendable {
    public var start: Date
    public var end: Date?
    public var text: String
    /// 本文の下に段落を分けて並べるリンク（Spotify の曲など。Nikky で埋め込みにできる）
    public var link: String?

    public init(start: Date, end: Date? = nil, text: String, link: String? = nil) {
        self.start = start
        self.end = end
        self.text = text
        self.link = link
    }
}

/// 朝日新聞「首相動静」の文体で一日を組み立てる。
///
/// 規則:
/// - 最初の時刻は「午前/午後」付きで書く
/// - 以降は「同」で受け、時が直前と同じなら「同５３分」、違えば「同９時４分」
/// - 午前→午後のように区分が変わったら「午後１時４７分」と書き直す
/// - 「〜から」で始まる時刻は、直前の時刻の1分後（続けている）でなければ
///   時が同じでも省略しない（「同５３分、駅着。同８時５９分から」「同４分まで、電車。同５分から」）
/// - ちょうどの時刻は「同９時」のように分を書かない
/// - 数字は全角
public struct DoseiFormatter: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = DoseiFormatter.japaneseCalendar) {
        self.calendar = calendar
    }

    public static var japaneseCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        cal.locale = Locale(identifier: "ja_JP")
        return cal
    }

    public func format(_ items: [TimelineItem]) -> String {
        let sorted =
            items
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.start < $1.start }
        guard !sorted.isEmpty else { return "" }

        var ref: Reference? = nil
        var sentences: [String] = []

        for item in sorted {
            let text = Self.trimPeriod(item.text)
            if let end = item.end, end > item.start {
                let s = render(item.start, ref: &ref, forceHour: true)
                let e = render(end, ref: &ref, forceHour: false)
                sentences.append("\(s)から\(e)まで、\(text)。")
            } else {
                let s = render(item.start, ref: &ref, forceHour: false)
                sentences.append("\(s)、\(text)。")
            }
        }

        let body = "\u{3000}" + sentences.joined()
        // リンクは本文に出てくる順に、1つずつ段落を分けて並べる（Nikky では段落が URL だけだと埋め込みにできる）
        let links = sorted.compactMap(\.link)
        return ([body] + links).joined(separator: "\n\n")
    }

    // MARK: - 時刻表現

    struct Reference {
        var isPM: Bool
        var hour12: Int
        var day: DateComponents
        var date: Date
    }

    func render(_ date: Date, ref: inout Reference?, forceHour: Bool) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let hour = c.hour!, minute = c.minute!
        let isPM = hour >= 12
        let hour12 = hour % 12
        let day = DateComponents(year: c.year, month: c.month, day: c.day)

        defer { ref = Reference(isPM: isPM, hour12: hour12, day: day, date: date) }

        let hm = minute == 0 ? "\(Self.zen(hour12))時" : "\(Self.zen(hour12))時\(Self.zen(minute))分"

        guard let r = ref, r.isPM == isPM, r.day == day else {
            // 最初の時刻、または午前/午後・日付が変わったとき
            return (isPM ? "午後" : "午前") + hm
        }
        let continues = date.timeIntervalSince(r.date) <= 60
        if r.hour12 == hour12 && (!forceHour || continues) && minute != 0 {
            return "同\(Self.zen(minute))分"
        }
        return "同" + hm
    }

    static func zen(_ n: Int) -> String {
        String(
            String(n).map { ch -> Character in
                guard let v = ch.wholeNumberValue else { return ch }
                return Character(UnicodeScalar(0xFF10 + v)!)
            })
    }

    static func trimPeriod(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = t.last, last == "。" || last == "." {
            t.removeLast()
        }
        return t
    }
}
