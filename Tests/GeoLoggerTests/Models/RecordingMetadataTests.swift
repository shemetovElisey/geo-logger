import XCTest
@testable import GeoLogger

final class RecordingMetadataTests: XCTestCase {
    func testMetadataEncoding() throws {
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(timeIntervalSince1970: 1704470400),
            device: "iPhone 15 Pro",
            systemVersion: "iOS 17.2",
            duration: 3600.5,
            eventCount: 245
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["version"] as? String, "1.0")
        XCTAssertEqual(json["device"] as? String, "iPhone 15 Pro")
        XCTAssertEqual(json["systemVersion"] as? String, "iOS 17.2")
        if let duration = json["duration"] as? Double {
            XCTAssertEqual(duration, 3600.5, accuracy: 0.01)
        } else {
            XCTFail("duration is not a Double")
        }
        XCTAssertEqual(json["eventCount"] as? Int, 245)
    }

    func testMetadataDecoding() throws {
        let json = """
        {
            "version": "1.0",
            "recordedAt": "2024-01-05T14:30:00Z",
            "device": "iPhone 15 Pro",
            "systemVersion": "iOS 17.2",
            "duration": 3600.5,
            "eventCount": 245
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(RecordingMetadata.self, from: json)

        XCTAssertEqual(metadata.version, "1.0")
        XCTAssertEqual(metadata.device, "iPhone 15 Pro")
        XCTAssertEqual(metadata.duration, 3600.5, accuracy: 0.01)
    }
}
