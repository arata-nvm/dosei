import XCTest
@testable import DoseiCore

final class DoseiFormatterTests: XCTestCase {
    let cal = DoseiFormatter.japaneseCalendar

    func t(_ h: Int, _ m: Int, day: Int = 2) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))!
    }

    /// 首相動静の文体の規則をひととおり確かめる（架空の1日）
    func testShushoDoseiRules() {
        let items: [TimelineItem] = [
            .init(start: t(8, 52), text: "自宅発"),
            .init(start: t(8, 53), text: "研究室着"),
            .init(start: t(8, 59), end: t(9, 4), text: "電車"),
            .init(start: t(9, 5), end: t(9, 6), text: "乗り換え"),
            .init(start: t(9, 7), end: t(9, 8), text: "バス"),
            .init(start: t(9, 9), end: t(9, 15), text: "コンビニ"),
            .init(start: t(11, 30), end: t(11, 42), text: "打ち合わせ"),
            .init(start: t(11, 43), end: t(11, 48), text: "片付け"),
            .init(start: t(13, 47), text: "研究室発"),
            .init(start: t(13, 55), text: "図書館着"),
            .init(start: t(14, 37), text: "図書館発"),
            .init(start: t(14, 47), text: "研究室着"),
            .init(start: t(15, 49), end: t(15, 54), text: "電話"),
            .init(start: t(16, 25), text: "研究室発"),
            .init(start: t(16, 27), text: "カフェ着"),
            .init(start: t(16, 41), text: "同所発"),
            .init(start: t(16, 42), text: "研究室着"),
            .init(start: t(16, 52), end: t(17, 12), text: "ゼミ"),
            .init(start: t(17, 17), end: t(17, 31), text: "雑談"),
            .init(start: t(18, 1), text: "研究室発"),
            .init(start: t(18, 2), text: "自宅着"),
        ]
        let expected = "\u{3000}"
            + "午前８時５２分、自宅発。同５３分、研究室着。同８時５９分から同９時４分まで、電車。"
            + "同５分から同６分まで、乗り換え。同７分から同８分まで、バス。"
            + "同９分から同１５分まで、コンビニ。同１１時３０分から同４２分まで、打ち合わせ。"
            + "同４３分から同４８分まで、片付け。午後１時４７分、研究室発。同５５分、図書館着。"
            + "同２時３７分、図書館発。同４７分、研究室着。同３時４９分から同５４分まで、電話。"
            + "同４時２５分、研究室発。同２７分、カフェ着。同４１分、同所発。同４２分、研究室着。"
            + "同４時５２分から同５時１２分まで、ゼミ。同５時１７分から同３１分まで、雑談。"
            + "同６時１分、研究室発。同２分、自宅着。"
        XCTAssertEqual(DoseiFormatter().format(items), expected)
    }

    func testExactHours() {
        let items: [TimelineItem] = [
            .init(start: t(9, 0), text: "大学着"),
            .init(start: t(10, 0), end: t(12, 0), text: "講義"),
            .init(start: t(12, 30), text: "昼食。"),
        ]
        XCTAssertEqual(
            DoseiFormatter().format(items),
            "\u{3000}午前９時、大学着。同１０時から午後０時まで、講義。同３０分、昼食。"
        )
    }

    func testAfterMidnightRestatesMeridiem() {
        let items: [TimelineItem] = [
            .init(start: t(23, 10), text: "帰宅"),
            .init(start: t(1, 30, day: 3), text: "就寝"),
        ]
        XCTAssertEqual(DoseiFormatter().format(items), "\u{3000}午後１１時１０分、帰宅。午前１時３０分、就寝。")
    }

    func testEmptyAndBlankItems() {
        XCTAssertEqual(DoseiFormatter().format([]), "")
        XCTAssertEqual(DoseiFormatter().format([.init(start: t(9, 0), text: "  ")]), "")
    }

    func testDiaryDayBoundary() {
        let d = DiaryDay(containing: t(2, 0, day: 3))
        XCTAssertEqual(d, DiaryDay(year: 2026, month: 11, day: 2))
        XCTAssertEqual(DiaryDay(containing: t(4, 0, day: 3)), DiaryDay(year: 2026, month: 11, day: 3))
        XCTAssertEqual(DiaryDay(year: 2026, month: 11, day: 3).title(), "11月3日（火）")
        XCTAssertEqual(DiaryDay(year: 2026, month: 11, day: 30).adding(days: 1), DiaryDay(year: 2026, month: 12, day: 1))
    }

    func testSleep() {
        let raw: [TimeSpan] = [
            .init(start: t(0, 40), end: t(3, 0)),
            .init(start: t(3, 20), end: t(7, 40)),   // 20分の中途覚醒はつなぐ
            .init(start: t(14, 0), end: t(14, 30)),  // 昼寝
            .init(start: t(23, 50), end: t(6, 0, day: 3)),
        ]
        let sessions = SleepAnalyzer.sessions(raw)
        XCTAssertEqual(sessions.count, 3)
        let r = SleepAnalyzer.wakeAndBed(sessions: sessions, day: DiaryDay(year: 2026, month: 11, day: 2))
        XCTAssertEqual(r.wake, t(7, 40))
        XCTAssertEqual(r.bed, t(23, 50))
    }
}
