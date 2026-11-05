import XCTest

@testable import DoseiCore

final class ImportTests: XCTestCase {
    let day = DiaryDay(year: 2026, month: 11, day: 3)

    func testDecodeCheckins() throws {
        let json = """
            {"meta":{"code":200},"response":{"checkins":{"count":2,"items":[
              {"id":"a1","createdAt":1762128900,"shout":"無視される","venue":{"name":"スターバックス 渋谷店"}},
              {"id":"b2","createdAt":1762140600}
            ]}}}
            """
        let checkins = try SwarmAPI.decodeCheckins(Data(json.utf8))
        XCTAssertEqual(checkins.count, 2)
        XCTAssertEqual(
            checkins[0].record,
            ImportedRecord(
                sourceID: "swarm-a1", kind: .checkin,
                start: Date(timeIntervalSince1970: 1762128900), text: "スターバックス 渋谷店"
            ))
        XCTAssertEqual(checkins[1].record.text, "（場所不明）")
    }

    func testCheckinsURL() {
        let url = SwarmAPI(token: "T").checkinsURL(
            from: Date(timeIntervalSince1970: 100), to: Date(timeIntervalSince1970: 200)
        )
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let q = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        XCTAssertEqual(url.host, "api.foursquare.com")
        XCTAssertEqual(q["oauth_token"], "T")
        XCTAssertEqual(q["afterTimestamp"], "100")
        XCTAssertEqual(q["beforeTimestamp"], "200")
    }

    func testTokenFromCallback() {
        XCTAssertEqual(SwarmAPI.token(fromCallback: URL(string: "dosei://swarm#access_token=XYZ")!), "XYZ")
        XCTAssertNil(SwarmAPI.token(fromCallback: URL(string: "dosei://swarm#error=denied")!))
        XCTAssertNil(SwarmAPI.token(fromCallback: URL(string: "dosei://swarm")!))
    }

    func testAuthorizeURL() {
        let url = SwarmAPI.authorizeURL(clientID: "CID")!
        XCTAssertTrue(url.absoluteString.contains("client_id=CID"))
        XCTAssertTrue(url.absoluteString.contains("response_type=token"))
    }

    /// 保存済みデータとの対応が崩れないよう、sourceID の形式を固定しておく
    func testSourceIDFormat() {
        XCTAssertEqual(SourceID.swarm("x"), "swarm-x")
        XCTAssertEqual(SourceID.wake(day), "hk-wake-2026-11-03")
        XCTAssertEqual(SourceID.bed(day), "hk-bed-2026-11-03")
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(SourceID.workout(uuid), "hk-workout-00000000-0000-0000-0000-000000000001")
        XCTAssertEqual(RecordKind.allCases.map(\.rawValue), ["memo", "wake", "sleep", "workout", "checkin", "music"])
    }

    func testSleepRecords() {
        let wake = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(
            ImportedRecord.sleep(wake: wake, bed: nil, day: day),
            [
                ImportedRecord(sourceID: "hk-wake-2026-11-03", kind: .wake, start: wake, text: "起床")
            ])
        XCTAssertEqual(ImportedRecord.sleep(wake: nil, bed: nil, day: day), [])
    }
}
