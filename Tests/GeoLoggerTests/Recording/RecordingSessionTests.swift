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
}
