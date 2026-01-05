import XCTest
import CoreLocation
@testable import GeoLogger

final class GPXExporterTests: XCTestCase {
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
    
    func testConvertToGPX() throws {
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(timeIntervalSince1970: 1704470400),
            device: "iPhone 15 Pro",
            systemVersion: "iOS 17.2",
            duration: 1.0,
            eventCount: 1
        )
        
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
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
        
        let recordingFile = RecordingFile(metadata: metadata, events: [event])
        let gpxString = GPXExporter.convertToGPX(recordingFile)
        
        // Verify GPX structure
        XCTAssertTrue(gpxString.contains("<?xml version=\"1.0\""))
        XCTAssertTrue(gpxString.contains("<gpx version=\"1.1\""))
        XCTAssertTrue(gpxString.contains("<trk>"))
        XCTAssertTrue(gpxString.contains("<trkpt"))
        XCTAssertTrue(gpxString.contains("lat=\"55.7558\""))
        XCTAssertTrue(gpxString.contains("lon=\"37.6173\""))
        XCTAssertTrue(gpxString.contains("<ele>150.5</ele>"))
    }
    
    func testExportToGPX() throws {
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(),
            device: "Test Device",
            systemVersion: "iOS 17.0",
            duration: 1.0,
            eventCount: 1
        )
        
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        
        let event = GeoEvent.location(
            timestamp: Date(),
            relativeTime: 0.0,
            location: location
        )
        
        let recordingFile = RecordingFile(metadata: metadata, events: [event])
        let outputURL = tempDirectory.appendingPathComponent("test.gpx")
        
        try GPXExporter.exportToGPX(recordingFile, to: outputURL)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        
        let data = try Data(contentsOf: outputURL)
        let gpxString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(gpxString.contains("<gpx"))
        XCTAssertTrue(gpxString.contains("test.gpx") || gpxString.contains("GeoLogger"))
    }
    
    func testGPXExcludesErrorEvents() throws {
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(),
            device: "Test",
            systemVersion: "iOS 17",
            duration: 1.0,
            eventCount: 2
        )
        
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )
        
        let error = NSError(domain: kCLErrorDomain, code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Test error"
        ])
        
        let events = [
            GeoEvent.location(timestamp: Date(), relativeTime: 0.0, location: location),
            GeoEvent.error(timestamp: Date(), relativeTime: 0.5, error: error)
        ]
        
        let recordingFile = RecordingFile(metadata: metadata, events: events)
        let gpxString = GPXExporter.convertToGPX(recordingFile)
        
        // Should contain location but not error
        XCTAssertTrue(gpxString.contains("<trkpt"))
        XCTAssertFalse(gpxString.contains("error"))
    }
}

