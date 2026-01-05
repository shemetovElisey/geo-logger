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

    func testConfigurationDefaults() {
        let config = GeoLoggerConfiguration()

        XCTAssertEqual(config.mode, .passthrough)
        XCTAssertNil(config.directory)
        XCTAssertEqual(config.replaySpeedMultiplier, 1.0)
        XCTAssertNil(config.replayFileName)
        XCTAssertFalse(config.loopReplay)
    }

    func testConfigurationCustomValues() {
        var config = GeoLoggerConfiguration()
        config.mode = .record
        config.replaySpeedMultiplier = 2.0
        config.loopReplay = true

        XCTAssertEqual(config.mode, .record)
        XCTAssertEqual(config.replaySpeedMultiplier, 2.0)
        XCTAssertTrue(config.loopReplay)
    }
}
