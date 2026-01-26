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
        // Step 1: Create a JSON recording file directly
        let startTime = Date()
        
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: startTime
        )

        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7559, longitude: 37.6174),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: startTime.addingTimeInterval(1.0)
        )

        let event1 = GeoEvent.location(timestamp: startTime, relativeTime: 0, location: location1)
        let event2 = GeoEvent.location(timestamp: startTime.addingTimeInterval(1.0), relativeTime: 1.0, location: location2)
        
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: startTime,
            device: "Test",
            systemVersion: "iOS 17",
            duration: 1.0,
            eventCount: 2
        )
        let recordingFile = RecordingFile(metadata: metadata, events: [event1, event2])
        
        // Write to file
        let jsonURL = tempDirectory.appendingPathComponent("test_recording.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(recordingFile)
        try data.write(to: jsonURL)
        
        // Step 2: Verify recording file exists
        let manager = RecordingManager(directory: tempDirectory)
        let recordings = manager.listRecordings()
        XCTAssertEqual(recordings.count, 1, "Should have one recording file")

        // Step 3: Replay from file
        var replayConfig = GeoLoggerConfiguration()
        replayConfig.mode = .replay
        replayConfig.replayFileURL = jsonURL
        replayConfig.replaySpeedMultiplier = 100.0 // Fast replay for tests

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
        replayLogger.delegate = replayDelegate

        replayLogger.startUpdatingLocation()

        wait(for: [expectation], timeout: 5.0)

        // Verify replayed locations match recorded ones
        XCTAssertEqual(replayDelegate.locations.count, 2)
        XCTAssertEqual(replayDelegate.locations[0].coordinate.latitude, 55.7558, accuracy: 0.0001)
        XCTAssertEqual(replayDelegate.locations[1].coordinate.latitude, 55.7559, accuracy: 0.0001)
    }
    
    func testRecordingSession() throws {
        // Test recording session directly - it uses CoreData as buffer and exports to JSON
        let session = try RecordingSession(directory: tempDirectory)
        
        let exportExpectation = expectation(description: "Export completed")
        session.onExportCompleted = { _ in
            exportExpectation.fulfill()
        }
        
        try session.start()
        XCTAssertTrue(session.isRecording)
        
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        
        session.recordLocation(location)
        
        // Give time for async write to CoreData
        Thread.sleep(forTimeInterval: 0.2)
        
        try session.stop()
        XCTAssertFalse(session.isRecording)
        
        // Wait for async export to complete
        wait(for: [exportExpectation], timeout: 5.0)
        
        // Verify recording file was created (CoreData exports to JSON on stop)
        let manager = RecordingManager(directory: tempDirectory)
        let recordings = manager.listRecordings()
        XCTAssertEqual(recordings.count, 1)
        XCTAssertEqual(recordings[0].eventCount, 1)
    }
}

