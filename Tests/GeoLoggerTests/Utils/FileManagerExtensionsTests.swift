import XCTest
import Foundation
@testable import GeoLogger

final class FileManagerExtensionsTests: XCTestCase {

    func testGeoLoggerDirectoryCreation() throws {
        let fileManager = FileManager.default
        let directory = try fileManager.geoLoggerDirectory()

        XCTAssertTrue(fileManager.fileExists(atPath: directory.path))

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory)
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testGenerateRecordingFileName() {
        let fileName = FileManager.generateRecordingFileName()

        XCTAssertTrue(fileName.hasPrefix("recording_"))
        XCTAssertTrue(fileName.hasSuffix(".geojson"))
    }

    func testGeneratedFileNamesAreUnique() {
        let fileName1 = FileManager.generateRecordingFileName()
        let fileName2 = FileManager.generateRecordingFileName()

        XCTAssertNotEqual(fileName1, fileName2)
    }
}
