import XCTest
import CoreLocation
@testable import GeoLogger

final class ReplaySessionTests: XCTestCase {
    var tempDirectory: URL!
    var testFileURL: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeoLoggerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create test recording file
        testFileURL = tempDirectory.appendingPathComponent("test_recording.json")
        createTestRecording()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func createTestRecording() {
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(),
            device: "Test Device",
            systemVersion: "iOS 17.0",
            duration: 2.0,
            eventCount: 2
        )

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

        let events = [
            GeoEvent.location(timestamp: Date(), relativeTime: 0.0, location: location1),
            GeoEvent.location(timestamp: Date().addingTimeInterval(1.0), relativeTime: 1.0, location: location2)
        ]

        let file = RecordingFile(metadata: metadata, events: events)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]

        let data = try! encoder.encode(file)
        try! data.write(to: testFileURL)
    }

    func testReplaySessionInitialization() throws {
        let session = try ReplaySession(
            fileURL: testFileURL,
            speedMultiplier: 1.0,
            loop: false
        )

        XCTAssertNotNil(session)
        XCTAssertFalse(session.isReplaying)
    }

    func testReplayPlayback() throws {
        let session = try ReplaySession(
            fileURL: testFileURL,
            speedMultiplier: 10.0, // 10x speed for fast test
            loop: false
        )

        let expectation = XCTestExpectation(description: "Received location updates")
        var receivedLocations: [CLLocation] = []

        session.onLocationUpdate = { locations in
            receivedLocations.append(contentsOf: locations)
            if receivedLocations.count >= 2 {
                expectation.fulfill()
            }
        }

        session.start()

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(receivedLocations.count, 2)
        XCTAssertEqual(receivedLocations[0].coordinate.latitude, 55.7558, accuracy: 0.0001)
        XCTAssertEqual(receivedLocations[1].coordinate.latitude, 55.7559, accuracy: 0.0001)
    }
    
    func testReplayGPXFile() throws {
        // Create a GPX file
        let gpxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GeoLogger">
            <trk>
                <trkseg>
                    <trkpt lat="55.7558" lon="37.6173">
                        <ele>150.0</ele>
                        <time>2026-01-05T14:30:01Z</time>
                    </trkpt>
                    <trkpt lat="55.7559" lon="37.6174">
                        <ele>151.0</ele>
                        <time>2026-01-05T14:30:02Z</time>
                    </trkpt>
                </trkseg>
            </trk>
        </gpx>
        """
        
        let gpxURL = tempDirectory.appendingPathComponent("test.gpx")
        try gpxContent.write(to: gpxURL, atomically: true, encoding: .utf8)
        
        let session = try ReplaySession(
            fileURL: gpxURL,
            speedMultiplier: 10.0,
            loop: false
        )
        
        let expectation = XCTestExpectation(description: "Received location updates from GPX")
        var receivedLocations: [CLLocation] = []
        
        session.onLocationUpdate = { locations in
            receivedLocations.append(contentsOf: locations)
            if receivedLocations.count >= 2 {
                expectation.fulfill()
            }
        }
        
        session.start()
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(receivedLocations.count, 2)
        XCTAssertEqual(receivedLocations[0].coordinate.latitude, 55.7558, accuracy: 0.0001)
        XCTAssertEqual(receivedLocations[1].coordinate.latitude, 55.7559, accuracy: 0.0001)
    }
}
