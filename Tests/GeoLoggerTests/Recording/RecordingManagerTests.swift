import XCTest
import CoreLocation
@testable import GeoLogger

final class RecordingManagerTests: XCTestCase {
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

    func testListRecordings() throws {
        let manager = RecordingManager(directory: tempDirectory)

        // Create test file
        let testFile = tempDirectory.appendingPathComponent("geo_log_2026-01-05_14-30-00.json")
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(),
            device: "Test",
            systemVersion: "iOS 17",
            duration: 100,
            eventCount: 10
        )
        let file = RecordingFile(metadata: metadata, events: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        try data.write(to: testFile)

        let recordings = manager.listRecordings()

        XCTAssertEqual(recordings.count, 1)
        XCTAssertEqual(recordings[0].name, "geo_log_2026-01-05_14-30-00.json")
        XCTAssertEqual(recordings[0].duration, 100, accuracy: 0.01)
        XCTAssertEqual(recordings[0].eventCount, 10)
    }

    func testDeleteRecording() throws {
        let manager = RecordingManager(directory: tempDirectory)

        // Create test file
        let testFile = tempDirectory.appendingPathComponent("test.json")
        try "{}".write(to: testFile, atomically: true, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        try manager.deleteRecording(name: "test.json")

        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))
    }

    func testExportRecording() throws {
        let manager = RecordingManager(directory: tempDirectory)

        // Create test file
        let testFile = tempDirectory.appendingPathComponent("test.json")
        try "{}".write(to: testFile, atomically: true, encoding: .utf8)

        let exportURL = manager.exportRecording(name: "test.json")

        XCTAssertEqual(exportURL, testFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
    }
    
    func testExportRecordingAsGPX() throws {
        let manager = RecordingManager(directory: tempDirectory)
        
        // Create a test JSON file with location event
        let testFile = tempDirectory.appendingPathComponent("test_gpx.json")
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(),
            device: "Test",
            systemVersion: "iOS 17",
            duration: 10,
            eventCount: 1
        )
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        let event = GeoEvent.location(timestamp: Date(), relativeTime: 0, location: location)
        let file = RecordingFile(metadata: metadata, events: [event])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        try data.write(to: testFile)

        let gpxURL = try manager.exportRecordingAsGPX(name: "test_gpx.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: gpxURL.path))
        XCTAssertTrue(gpxURL.lastPathComponent.hasSuffix(".gpx"))
        
        // Verify GPX content
        let gpxContent = try String(contentsOf: gpxURL, encoding: .utf8)
        XCTAssertTrue(gpxContent.contains("<gpx"))
        XCTAssertTrue(gpxContent.contains("lat=\"55.7558\""))
    }
}

