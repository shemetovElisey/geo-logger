import XCTest
import CoreLocation
@testable import GeoLogger

final class GeoLoggerDelegateTests: XCTestCase {
    class TestDelegate: GeoLoggerDelegate {
        var locations: [CLLocation] = []
        var errors: [Error] = []

        func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {
            self.locations.append(contentsOf: locations)
        }

        func geoLogger(_ logger: GeoLogger, didFailWithError error: Error) {
            self.errors.append(error)
        }
    }

    func testDelegateConformance() {
        let delegate = TestDelegate()

        XCTAssertNotNil(delegate)
        XCTAssertEqual(delegate.locations.count, 0)
        XCTAssertEqual(delegate.errors.count, 0)
    }
}

