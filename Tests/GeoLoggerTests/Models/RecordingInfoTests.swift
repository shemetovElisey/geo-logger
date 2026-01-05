import XCTest
@testable import GeoLogger

final class RecordingInfoTests: XCTestCase {
    func testRecordingInfoProperties() {
        let date = Date(timeIntervalSince1970: 1704470400)
        let info = RecordingInfo(
            name: "geo_log_2026-01-05_14-30-00.json",
            date: date,
            size: 125000,
            duration: 3600.5,
            eventCount: 245
        )

        XCTAssertEqual(info.name, "geo_log_2026-01-05_14-30-00.json")
        XCTAssertEqual(info.date, date)
        XCTAssertEqual(info.size, 125000)
        XCTAssertEqual(info.duration, 3600.5, accuracy: 0.01)
        XCTAssertEqual(info.eventCount, 245)
    }
}
