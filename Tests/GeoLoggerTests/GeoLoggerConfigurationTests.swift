import XCTest
@testable import GeoLogger

final class GeoLoggerConfigurationTests: XCTestCase {
    func testModeEnumCases() {
        let record = GeoLoggerMode.record
        let replay = GeoLoggerMode.replay
        let passthrough = GeoLoggerMode.passthrough

        XCTAssertNotNil(record)
        XCTAssertNotNil(replay)
        XCTAssertNotNil(passthrough)
    }
}
