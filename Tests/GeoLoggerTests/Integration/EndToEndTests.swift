import XCTest
import CoreLocation
@testable import GeoLogger

final class EndToEndTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeoLoggerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testRecordAndReplay() throws {
        // Step 1: Record
        var recordConfig = GeoLoggerConfiguration()
        recordConfig.mode = .record
        recordConfig.directory = tempDirectory

        let recordLogger = GeoLogger(configuration: recordConfig)

        class RecordDelegate: NSObject, CLLocationManagerDelegate {
            var locations: [CLLocation] = []

            func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
                self.locations.append(contentsOf: locations)
            }
        }

        let recordDelegate = RecordDelegate()
        recordLogger.locationManagerDelegate = recordDelegate
        recordLogger.startUpdatingLocation()

        // Simulate location updates by calling CLLocationManagerDelegate methods directly
        // (in real scenario CLLocationManager would call these)
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )

        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7559, longitude: 37.6174),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date().addingTimeInterval(1.0)
        )

        // Simulate CLLocationManager calling delegate methods
        // Create a mock manager just for the test
        let mockManager = CLLocationManager()
        recordLogger.locationManager(mockManager, didUpdateLocations: [location1])
        Thread.sleep(forTimeInterval: 0.1)
        recordLogger.locationManager(mockManager, didUpdateLocations: [location2])
        Thread.sleep(forTimeInterval: 0.1)

        recordLogger.stopUpdatingLocation()

        // Give time for async file write
        Thread.sleep(forTimeInterval: 0.5)

        // Step 2: Verify recording file exists
        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "Should have created one recording file")

        let recordingFileName = files[0].lastPathComponent

        // Step 3: Replay
        var replayConfig = GeoLoggerConfiguration()
        replayConfig.mode = .replay
        replayConfig.directory = tempDirectory
        replayConfig.replayFileName = recordingFileName
        replayConfig.replaySpeedMultiplier = 10.0

        let replayLogger = GeoLogger(configuration: replayConfig)

        class ReplayDelegate: NSObject, CLLocationManagerDelegate {
            let expectation: XCTestExpectation
            var locations: [CLLocation] = []

            init(expectation: XCTestExpectation) {
                self.expectation = expectation
            }

            func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
                self.locations.append(contentsOf: locations)
                if self.locations.count >= 2 {
                    expectation.fulfill()
                }
            }
        }

        let expectation = XCTestExpectation(description: "Replay locations")
        let replayDelegate = ReplayDelegate(expectation: expectation)
        replayLogger.locationManagerDelegate = replayDelegate

        replayLogger.startUpdatingLocation()

        wait(for: [expectation], timeout: 5.0)

        // Verify replayed locations match recorded ones
        XCTAssertEqual(replayDelegate.locations.count, 2)
        XCTAssertEqual(replayDelegate.locations[0].coordinate.latitude, 55.7558, accuracy: 0.0001)
        XCTAssertEqual(replayDelegate.locations[1].coordinate.latitude, 55.7559, accuracy: 0.0001)
    }
}

