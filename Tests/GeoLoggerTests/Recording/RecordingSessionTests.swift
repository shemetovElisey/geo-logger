import XCTest
import CoreLocation
@testable import GeoLogger

final class RecordingSessionTests: XCTestCase {
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

    func testRecordingSessionInitialization() throws {
        let session = try RecordingSession(directory: tempDirectory)

        XCTAssertNotNil(session)
        XCTAssertFalse(session.isRecording)
    }

    func testStartRecording() throws {
        let session = try RecordingSession(directory: tempDirectory)

        try session.start()

        XCTAssertTrue(session.isRecording)
    }

    func testRecordLocation() throws {
        let session = try RecordingSession(directory: tempDirectory)
        try session.start()

        let coordinate = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 150.5,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 15.0,
            timestamp: Date()
        )

        session.recordLocation(location)

        // Give async queue time to process
        Thread.sleep(forTimeInterval: 0.1)

        try session.stop()

        // Verify file was created
        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].lastPathComponent.hasPrefix("geo_log_"))

        // Verify file content
        let data = try Data(contentsOf: files[0])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let recordingFile = try decoder.decode(RecordingFile.self, from: data)

        XCTAssertEqual(recordingFile.events.count, 1)
        XCTAssertEqual(recordingFile.metadata.eventCount, 1)
    }
}
