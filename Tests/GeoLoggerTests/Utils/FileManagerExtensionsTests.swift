import XCTest
@testable import GeoLogger

final class FileManagerExtensionsTests: XCTestCase {
    func testGeoLoggerDirectory() throws {
        let directory = try FileManager.default.geoLoggerDirectory(customDirectory: nil)

        XCTAssertTrue(directory.path.contains("Documents"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    func testCustomDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeoLoggerTest", isDirectory: true)

        let directory = try FileManager.default.geoLoggerDirectory(customDirectory: tempDir)

        XCTAssertEqual(directory, tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testGenerateFileName() {
        let fileName = FileManager.generateRecordingFileName()

        XCTAssertTrue(fileName.hasPrefix("geo_log_"))
        XCTAssertTrue(fileName.hasSuffix(".json"))
    }
}
