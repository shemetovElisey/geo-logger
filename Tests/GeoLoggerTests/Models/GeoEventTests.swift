import XCTest
import CoreLocation
@testable import GeoLogger

final class GeoEventTests: XCTestCase {
    func testLocationEventEncoding() throws {
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

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["type"] as? String, "location")
        XCTAssertEqual((json["relativeTime"] as? Double) ?? 0.0, 1.0, accuracy: 0.01)
        XCTAssertNotNil(json["data"])
    }

    func testErrorEventEncoding() throws {
        let error = NSError(domain: kCLErrorDomain, code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Location services denied"
        ])

        let event = GeoEvent.error(
            timestamp: Date(timeIntervalSince1970: 1704470535),
            relativeTime: 135.0,
            error: error
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["type"] as? String, "error")
        XCTAssertEqual((json["relativeTime"] as? Double) ?? 0.0, 135.0, accuracy: 0.01)
        XCTAssertEqual(json["code"] as? Int, 0)
        XCTAssertEqual(json["domain"] as? String, kCLErrorDomain)
    }

    func testLocationEventRoundTrip() throws {
        // Test that encode → decode preserves critical properties
        let coordinate = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        let originalLocation = CLLocation(
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
            location: originalLocation
        )

        // Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GeoEvent.self, from: data)

        // Verify critical properties preserved
        if case .location(_, _, let decodedLocation) = decoded {
            XCTAssertEqual(decodedLocation.coordinate.latitude, originalLocation.coordinate.latitude, accuracy: 0.0001)
            XCTAssertEqual(decodedLocation.coordinate.longitude, originalLocation.coordinate.longitude, accuracy: 0.0001)
            XCTAssertEqual(decodedLocation.altitude, originalLocation.altitude, accuracy: 0.01)
            XCTAssertEqual(decodedLocation.horizontalAccuracy, originalLocation.horizontalAccuracy, accuracy: 0.01)
            XCTAssertEqual(decodedLocation.verticalAccuracy, originalLocation.verticalAccuracy, accuracy: 0.01)
            XCTAssertEqual(decodedLocation.course, originalLocation.course, accuracy: 0.01)
            XCTAssertEqual(decodedLocation.speed, originalLocation.speed, accuracy: 0.01)
            // Note: courseAccuracy, speedAccuracy, floor, etc. are NOT preserved due to CLLocation API limitations
        } else {
            XCTFail("Expected location event")
        }
    }
}
