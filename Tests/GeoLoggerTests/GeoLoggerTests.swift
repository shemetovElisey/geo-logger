import XCTest
import CoreLocation
@testable import GeoLogger

final class GeoLoggerTests: XCTestCase {
    func testInitialization() {
        let config = GeoLoggerConfiguration()
        let logger = GeoLogger(configuration: config)

        XCTAssertNotNil(logger)
    }

    func testPassthroughMode() {
        var config = GeoLoggerConfiguration()
        config.mode = .passthrough

        let logger = GeoLogger(configuration: config)
        logger.startUpdatingLocation()
        logger.stopUpdatingLocation()

        // Should not crash
        XCTAssertNotNil(logger)
    }
}

