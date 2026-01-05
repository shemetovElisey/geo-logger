import XCTest
import CoreLocation
@testable import GeoLogger

final class RecordingFileTests: XCTestCase {
    func testRecordingFileEncoding() throws {
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(timeIntervalSince1970: 1704470400),
            device: "iPhone 15 Pro",
            systemVersion: "iOS 17.2",
            duration: 1.0,
            eventCount: 1
        )

        let coordinate = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 150.5,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 15.0,
            course: 180.0,
            speed: 1.5,
            timestamp: Date(timeIntervalSince1970: 1704470401)
        )

        let event = GeoEvent.location(
            timestamp: Date(timeIntervalSince1970: 1704470401),
            relativeTime: 1.0,
            location: location
        )

        let file = RecordingFile(metadata: metadata, events: [event])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)

        XCTAssertGreaterThan(data.count, 0)

        // Verify it can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RecordingFile.self, from: data)

        XCTAssertEqual(decoded.metadata.version, "1.0")
        XCTAssertEqual(decoded.events.count, 1)
    }
}
