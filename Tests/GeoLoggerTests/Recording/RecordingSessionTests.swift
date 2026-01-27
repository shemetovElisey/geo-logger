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
        
        try session.stop()
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
        Thread.sleep(forTimeInterval: 0.2)

        try session.stop()

        // Verify JSON file was created
        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        XCTAssertEqual(jsonFiles.count, 1)
        
        let fileURL = jsonFiles[0]
        XCTAssertTrue(fileURL.lastPathComponent.hasPrefix("geo_log_"))
        
        // Verify file content
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let recordingFile = try decoder.decode(RecordingFile.self, from: data)
        
        XCTAssertEqual(recordingFile.events.count, 1)
        XCTAssertEqual(recordingFile.metadata.eventCount, 1)
        
        // Verify location data
        if case .location(_, _, let recordedLocation) = recordingFile.events[0] {
            XCTAssertEqual(recordedLocation.coordinate.latitude, 55.7558, accuracy: 0.0001)
            XCTAssertEqual(recordedLocation.coordinate.longitude, 37.6173, accuracy: 0.0001)
            XCTAssertEqual(recordedLocation.altitude, 150.5, accuracy: 0.1)
        } else {
            XCTFail("Expected location event")
        }
    }
    
    func testRecordError() throws {
        let session = try RecordingSession(directory: tempDirectory)
        try session.start()

        let error = NSError(domain: "TestDomain", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Test error"
        ])

        session.recordError(error)

        // Give async queue time to process
        Thread.sleep(forTimeInterval: 0.2)

        try session.stop()

        // Verify JSON file was created
        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        XCTAssertEqual(jsonFiles.count, 1)
        
        // Verify file content
        let data = try Data(contentsOf: jsonFiles[0])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let recordingFile = try decoder.decode(RecordingFile.self, from: data)
        
        XCTAssertEqual(recordingFile.events.count, 1)
        
        // Verify error event
        if case .error(_, _, let recordedError) = recordingFile.events[0] {
            let nsError = recordedError as NSError
            XCTAssertEqual(nsError.domain, "TestDomain")
            XCTAssertEqual(nsError.code, 42)
        } else {
            XCTFail("Expected error event")
        }
    }
}
