import XCTest
import CoreLocation
@testable import GeoLogger

final class GPXParserTests: XCTestCase {
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
    
    func testParseGPXFile() throws {
        // Create a simple GPX file
        let gpxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GeoLogger">
            <metadata>
                <name>Test Device</name>
                <time>2026-01-05T14:30:00Z</time>
            </metadata>
            <trk>
                <name>Test Track</name>
                <trkseg>
                    <trkpt lat="55.7558" lon="37.6173">
                        <ele>150.5</ele>
                        <time>2026-01-05T14:30:01Z</time>
                    </trkpt>
                    <trkpt lat="55.7559" lon="37.6174">
                        <ele>151.0</ele>
                        <time>2026-01-05T14:30:02Z</time>
                    </trkpt>
                </trkseg>
            </trk>
        </gpx>
        """
        
        let gpxURL = tempDirectory.appendingPathComponent("test.gpx")
        try gpxContent.write(to: gpxURL, atomically: true, encoding: .utf8)
        
        let recordingFile = try GPXParser.parseGPX(from: gpxURL)
        
        XCTAssertEqual(recordingFile.events.count, 2)
        XCTAssertEqual(recordingFile.metadata.eventCount, 2)
        
        // Check first location
        if case .location(_, _, let location1) = recordingFile.events[0] {
            XCTAssertEqual(location1.coordinate.latitude, 55.7558, accuracy: 0.0001)
            XCTAssertEqual(location1.coordinate.longitude, 37.6173, accuracy: 0.0001)
            XCTAssertEqual(location1.altitude, 150.5, accuracy: 0.1)
        } else {
            XCTFail("First event should be a location")
        }
    }
    
    func testParseGPXWithExtensions() throws {
        let gpxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1">
            <trk>
                <trkseg>
                    <trkpt lat="55.7558" lon="37.6173">
                        <ele>150.5</ele>
                        <time>2026-01-05T14:30:01Z</time>
                        <extensions>
                            <horizontalAccuracy>10.0</horizontalAccuracy>
                            <verticalAccuracy>15.0</verticalAccuracy>
                            <speed>1.5</speed>
                            <course>180.0</course>
                        </extensions>
                    </trkpt>
                </trkseg>
            </trk>
        </gpx>
        """
        
        let recordingFile = try GPXParser.parseGPXString(gpxContent)
        
        XCTAssertEqual(recordingFile.events.count, 1)
        
        if case .location(_, _, let location) = recordingFile.events[0] {
            XCTAssertEqual(location.horizontalAccuracy, 10.0, accuracy: 0.1)
            XCTAssertEqual(location.verticalAccuracy, 15.0, accuracy: 0.1)
            XCTAssertEqual(location.speed, 1.5, accuracy: 0.1)
            XCTAssertEqual(location.course, 180.0, accuracy: 0.1)
        } else {
            XCTFail("Event should be a location")
        }
    }
    
    func testParseGPXData() throws {
        let gpxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1">
            <trk>
                <trkseg>
                    <trkpt lat="55.7558" lon="37.6173">
                        <ele>150.5</ele>
                        <time>2026-01-05T14:30:01Z</time>
                    </trkpt>
                </trkseg>
            </trk>
        </gpx>
        """
        
        let data = gpxContent.data(using: .utf8)!
        let recordingFile = try GPXParser.parseGPX(from: data)
        
        XCTAssertEqual(recordingFile.events.count, 1)
    }
}

