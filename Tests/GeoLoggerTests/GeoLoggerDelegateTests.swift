import XCTest
import CoreLocation
@testable import GeoLogger

final class GeoLoggerDelegateTests: XCTestCase {
    class TestDelegate: GeoLoggerDelegate {
        var progressUpdates: [(Double, TimeInterval)] = []

        func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval) {
            progressUpdates.append((progress, currentTime))
        }
    }

    func testDelegateConformance() {
        let delegate = TestDelegate()

        XCTAssertNotNil(delegate)
        XCTAssertEqual(delegate.progressUpdates.count, 0)
    }
    
    func testProgressUpdate() {
        let delegate = TestDelegate()
        let logger = GeoLogger(configuration: GeoLoggerConfiguration())
        
        delegate.geoLogger(logger, didUpdateReplayProgress: 0.5, currentTime: 10.0)
        
        XCTAssertEqual(delegate.progressUpdates.count, 1)
        XCTAssertEqual(delegate.progressUpdates[0].0, 0.5, accuracy: 0.001)
        XCTAssertEqual(delegate.progressUpdates[0].1, 10.0, accuracy: 0.001)
    }
}

