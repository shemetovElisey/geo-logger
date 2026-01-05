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
}
