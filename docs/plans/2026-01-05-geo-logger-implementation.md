# GeoLogger iOS SDK Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build iOS SDK for recording and replaying CLLocationManager geodata for debugging

**Architecture:** Wrapper around CLLocationManager with three modes (Record/Replay/Passthrough). Recording serializes CLLocation to JSON with metadata. Replay reads JSON and reproduces events with accurate timing using DispatchQueue.

**Tech Stack:** Swift 5.9, iOS 14+, CoreLocation, Swift Package Manager, XCTest

---

## Phase 1: Project Setup

### Task 1: Create SPM Package Structure

**Files:**
- Create: `Package.swift`
- Create: `Sources/GeoLogger/.gitkeep`
- Create: `Tests/GeoLoggerTests/.gitkeep`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeoLogger",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "GeoLogger",
            targets: ["GeoLogger"]
        )
    ],
    targets: [
        .target(
            name: "GeoLogger",
            dependencies: []
        ),
        .testTarget(
            name: "GeoLoggerTests",
            dependencies: ["GeoLogger"]
        )
    ]
)
```

**Step 2: Create directory structure**

```bash
mkdir -p Sources/GeoLogger
mkdir -p Tests/GeoLoggerTests
touch Sources/GeoLogger/.gitkeep
touch Tests/GeoLoggerTests/.gitkeep
```

**Step 3: Verify SPM structure**

Run: `swift build`
Expected: "Build complete!" or warning about empty target (acceptable for now)

**Step 4: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "chore: initialize SPM package structure"
```

---

## Phase 2: Configuration Models

### Task 2: GeoLoggerMode Enum

**Files:**
- Create: `Sources/GeoLogger/GeoLoggerConfiguration.swift`
- Create: `Tests/GeoLoggerTests/GeoLoggerConfigurationTests.swift`

**Step 1: Write failing test**

Create `Tests/GeoLoggerTests/GeoLoggerConfigurationTests.swift`:

```swift
import XCTest
@testable import GeoLogger

final class GeoLoggerConfigurationTests: XCTestCase {
    func testModeEnumCases() {
        let record = GeoLoggerMode.record
        let replay = GeoLoggerMode.replay
        let passthrough = GeoLoggerMode.passthrough

        XCTAssertNotNil(record)
        XCTAssertNotNil(replay)
        XCTAssertNotNil(passthrough)
    }
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter GeoLoggerConfigurationTests`
Expected: FAIL with "Cannot find 'GeoLoggerMode' in scope"

**Step 3: Implement GeoLoggerMode**

Create `Sources/GeoLogger/GeoLoggerConfiguration.swift`:

```swift
import Foundation

/// Operating mode for GeoLogger
public enum GeoLoggerMode {
    /// Record location updates to JSON file
    case record
    /// Replay location updates from JSON file
    case replay
    /// Pass through to real CLLocationManager without logging
    case passthrough
}
```

**Step 4: Run test to verify pass**

Run: `swift test --filter GeoLoggerConfigurationTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/GeoLogger/GeoLoggerConfiguration.swift Tests/GeoLoggerTests/GeoLoggerConfigurationTests.swift
git commit -m "feat: add GeoLoggerMode enum"
```

---

### Task 3: GeoLoggerConfiguration Struct

**Files:**
- Modify: `Sources/GeoLogger/GeoLoggerConfiguration.swift`
- Modify: `Tests/GeoLoggerTests/GeoLoggerConfigurationTests.swift`

**Step 1: Write failing test**

Add to `Tests/GeoLoggerTests/GeoLoggerConfigurationTests.swift`:

```swift
func testConfigurationDefaults() {
    let config = GeoLoggerConfiguration()

    XCTAssertEqual(config.mode, .passthrough)
    XCTAssertNil(config.directory)
    XCTAssertEqual(config.replaySpeedMultiplier, 1.0)
    XCTAssertNil(config.replayFileName)
    XCTAssertFalse(config.loopReplay)
}

func testConfigurationCustomValues() {
    var config = GeoLoggerConfiguration()
    config.mode = .record
    config.replaySpeedMultiplier = 2.0
    config.loopReplay = true

    XCTAssertEqual(config.mode, .record)
    XCTAssertEqual(config.replaySpeedMultiplier, 2.0)
    XCTAssertTrue(config.loopReplay)
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter GeoLoggerConfigurationTests`
Expected: FAIL with "Cannot find 'GeoLoggerConfiguration' in scope"

**Step 3: Implement GeoLoggerConfiguration**

Add to `Sources/GeoLogger/GeoLoggerConfiguration.swift`:

```swift
/// Configuration for GeoLogger behavior
public struct GeoLoggerConfiguration {
    /// Operating mode (record, replay, or passthrough)
    public var mode: GeoLoggerMode = .passthrough

    /// Directory for storing/reading recordings. Defaults to Documents directory
    public var directory: URL? = nil

    /// Speed multiplier for replay (1.0 = real-time, 2.0 = double speed)
    public var replaySpeedMultiplier: Double = 1.0

    /// File name for replay mode
    public var replayFileName: String? = nil

    /// Whether to loop replay when it ends
    public var loopReplay: Bool = false

    public init() {}
}
```

**Step 4: Run test to verify pass**

Run: `swift test --filter GeoLoggerConfigurationTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/GeoLogger/GeoLoggerConfiguration.swift Tests/GeoLoggerTests/GeoLoggerConfigurationTests.swift
git commit -m "feat: add GeoLoggerConfiguration struct"
```

---

## Phase 3: Data Models

### Task 4: RecordingMetadata Model

**Files:**
- Create: `Sources/GeoLogger/Models/RecordingMetadata.swift`
- Create: `Tests/GeoLoggerTests/Models/RecordingMetadataTests.swift`

**Step 1: Create directory**

```bash
mkdir -p Sources/GeoLogger/Models
mkdir -p Tests/GeoLoggerTests/Models
```

**Step 2: Write failing test**

Create `Tests/GeoLoggerTests/Models/RecordingMetadataTests.swift`:

```swift
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
        XCTAssertEqual(json["duration"] as? Double, 3600.5, accuracy: 0.01)
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
```

**Step 3: Run test to verify failure**

Run: `swift test --filter RecordingMetadataTests`
Expected: FAIL with "Cannot find 'RecordingMetadata' in scope"

**Step 4: Implement RecordingMetadata**

Create `Sources/GeoLogger/Models/RecordingMetadata.swift`:

```swift
import Foundation

/// Metadata about a recording session
struct RecordingMetadata: Codable {
    /// Format version for compatibility
    let version: String

    /// When the recording started
    let recordedAt: Date

    /// Device model (e.g., "iPhone 15 Pro")
    let device: String

    /// OS version (e.g., "iOS 17.2")
    let systemVersion: String

    /// Total duration of recording in seconds
    let duration: TimeInterval

    /// Total number of events recorded
    let eventCount: Int
}
```

**Step 5: Run test to verify pass**

Run: `swift test --filter RecordingMetadataTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/GeoLogger/Models/RecordingMetadata.swift Tests/GeoLoggerTests/Models/RecordingMetadataTests.swift
git commit -m "feat: add RecordingMetadata model"
```

---

### Task 5: GeoEvent Model

**Files:**
- Create: `Sources/GeoLogger/Models/GeoEvent.swift`
- Create: `Tests/GeoLoggerTests/Models/GeoEventTests.swift`

**Step 1: Write failing test**

Create `Tests/GeoLoggerTests/Models/GeoEventTests.swift`:

```swift
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
        XCTAssertEqual(json["relativeTime"] as? Double, 1.0, accuracy: 0.01)
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
        XCTAssertEqual(json["relativeTime"] as? Double, 135.0, accuracy: 0.01)
        XCTAssertEqual(json["code"] as? Int, 0)
        XCTAssertEqual(json["domain"] as? String, kCLErrorDomain)
    }
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter GeoEventTests`
Expected: FAIL with "Cannot find 'GeoEvent' in scope"

**Step 3: Implement GeoEvent (part 1 - basic structure)**

Create `Sources/GeoLogger/Models/GeoEvent.swift`:

```swift
import Foundation
import CoreLocation

/// Event in a recording (location update or error)
enum GeoEvent: Codable {
    case location(timestamp: Date, relativeTime: TimeInterval, location: CLLocation)
    case error(timestamp: Date, relativeTime: TimeInterval, error: Error)

    enum CodingKeys: String, CodingKey {
        case type, timestamp, relativeTime, data, code, domain, description
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .location(let timestamp, let relativeTime, let location):
            try container.encode("location", forKey: .type)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(relativeTime, forKey: .relativeTime)

            let locationData = try LocationData(location: location)
            try container.encode(locationData, forKey: .data)

        case .error(let timestamp, let relativeTime, let error):
            try container.encode("error", forKey: .type)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(relativeTime, forKey: .relativeTime)

            let nsError = error as NSError
            try container.encode(nsError.code, forKey: .code)
            try container.encode(nsError.domain, forKey: .domain)
            try container.encode(nsError.localizedDescription, forKey: .description)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let relativeTime = try container.decode(TimeInterval.self, forKey: .relativeTime)

        switch type {
        case "location":
            let locationData = try container.decode(LocationData.self, forKey: .data)
            let location = locationData.toCLLocation()
            self = .location(timestamp: timestamp, relativeTime: relativeTime, location: location)

        case "error":
            let code = try container.decode(Int.self, forKey: .code)
            let domain = try container.decode(String.self, forKey: .domain)
            let description = try container.decode(String.self, forKey: .description)
            let error = NSError(domain: domain, code: code, userInfo: [
                NSLocalizedDescriptionKey: description
            ])
            self = .error(timestamp: timestamp, relativeTime: relativeTime, error: error)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown event type: \(type)"
            )
        }
    }
}

/// Codable representation of CLLocation
private struct LocationData: Codable {
    let coordinate: CoordinateData
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let course: Double
    let courseAccuracy: Double
    let speed: Double
    let speedAccuracy: Double
    let floor: Int?
    let timestamp: Date
    let ellipsoidalAltitude: Double?
    let sourceInformation: SourceInformationData?

    struct CoordinateData: Codable {
        let latitude: Double
        let longitude: Double
    }

    struct SourceInformationData: Codable {
        let isSimulatedBySoftware: Bool
        let isProducedByAccessory: Bool
    }

    init(location: CLLocation) throws {
        self.coordinate = CoordinateData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.course = location.course
        self.courseAccuracy = location.courseAccuracy
        self.speed = location.speed
        self.speedAccuracy = location.speedAccuracy
        self.floor = location.floor?.level
        self.timestamp = location.timestamp

        if #available(iOS 15.0, *) {
            self.ellipsoidalAltitude = location.ellipsoidalAltitude
            self.sourceInformation = location.sourceInformation.map {
                SourceInformationData(
                    isSimulatedBySoftware: $0.isSimulatedBySoftware,
                    isProducedByAccessory: $0.isProducedByAccessory
                )
            }
        } else {
            self.ellipsoidalAltitude = nil
            self.sourceInformation = nil
        }
    }

    func toCLLocation() -> CLLocation {
        let coordinate = CLLocationCoordinate2D(
            latitude: self.coordinate.latitude,
            longitude: self.coordinate.longitude
        )

        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}
```

**Step 4: Run test to verify pass**

Run: `swift test --filter GeoEventTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/GeoLogger/Models/GeoEvent.swift Tests/GeoLoggerTests/Models/GeoEventTests.swift
git commit -m "feat: add GeoEvent model with location and error cases"
```

---

### Task 6: RecordingInfo Model

**Files:**
- Create: `Sources/GeoLogger/Models/RecordingInfo.swift`
- Create: `Tests/GeoLoggerTests/Models/RecordingInfoTests.swift`

**Step 1: Write failing test**

Create `Tests/GeoLoggerTests/Models/RecordingInfoTests.swift`:

```swift
import XCTest
@testable import GeoLogger

final class RecordingInfoTests: XCTestCase {
    func testRecordingInfoProperties() {
        let date = Date(timeIntervalSince1970: 1704470400)
        let info = RecordingInfo(
            name: "geo_log_2026-01-05_14-30-00.json",
            date: date,
            size: 125000,
            duration: 3600.5,
            eventCount: 245
        )

        XCTAssertEqual(info.name, "geo_log_2026-01-05_14-30-00.json")
        XCTAssertEqual(info.date, date)
        XCTAssertEqual(info.size, 125000)
        XCTAssertEqual(info.duration, 3600.5, accuracy: 0.01)
        XCTAssertEqual(info.eventCount, 245)
    }
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter RecordingInfoTests`
Expected: FAIL with "Cannot find 'RecordingInfo' in scope"

**Step 3: Implement RecordingInfo**

Create `Sources/GeoLogger/Models/RecordingInfo.swift`:

```swift
import Foundation

/// Information about a recorded session file
public struct RecordingInfo {
    /// File name of the recording
    public let name: String

    /// Date when recording was created
    public let date: Date

    /// File size in bytes
    public let size: Int64

    /// Duration of recording in seconds
    public let duration: TimeInterval

    /// Number of events in recording
    public let eventCount: Int

    public init(name: String, date: Date, size: Int64, duration: TimeInterval, eventCount: Int) {
        self.name = name
        self.date = date
        self.size = size
        self.duration = duration
        self.eventCount = eventCount
    }
}
```

**Step 4: Run test to verify pass**

Run: `swift test --filter RecordingInfoTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/GeoLogger/Models/RecordingInfo.swift Tests/GeoLoggerTests/Models/RecordingInfoTests.swift
git commit -m "feat: add RecordingInfo model"
```

---

## Phase 4: JSON Serialization

### Task 7: RecordingFile Model

**Files:**
- Create: `Sources/GeoLogger/Models/RecordingFile.swift`
- Create: `Tests/GeoLoggerTests/Models/RecordingFileTests.swift`

**Step 1: Write failing test**

Create `Tests/GeoLoggerTests/Models/RecordingFileTests.swift`:

```swift
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
```

**Step 2: Run test to verify failure**

Run: `swift test --filter RecordingFileTests`
Expected: FAIL with "Cannot find 'RecordingFile' in scope"

**Step 3: Implement RecordingFile**

Create `Sources/GeoLogger/Models/RecordingFile.swift`:

```swift
import Foundation

/// Complete recording file structure
struct RecordingFile: Codable {
    /// Metadata about the recording
    let metadata: RecordingMetadata

    /// Array of events (locations and errors)
    let events: [GeoEvent]
}
```

**Step 4: Run test to verify pass**

Run: `swift test --filter RecordingFileTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/GeoLogger/Models/RecordingFile.swift Tests/GeoLoggerTests/Models/RecordingFileTests.swift
git commit -m "feat: add RecordingFile model"
```

---

## Phase 5: File Manager Utilities

### Task 8: FileManager Extensions

**Files:**
- Create: `Sources/GeoLogger/Utils/FileManager+Extensions.swift`
- Create: `Tests/GeoLoggerTests/Utils/FileManagerExtensionsTests.swift`

**Step 1: Create directory**

```bash
mkdir -p Sources/GeoLogger/Utils
mkdir -p Tests/GeoLoggerTests/Utils
```

**Step 2: Write failing test**

Create `Tests/GeoLoggerTests/Utils/FileManagerExtensionsTests.swift`:

```swift
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
```

**Step 3: Run test to verify failure**

Run: `swift test --filter FileManagerExtensionsTests`
Expected: FAIL with "Type 'FileManager' has no member 'geoLoggerDirectory'"

**Step 4: Implement FileManager extensions**

Create `Sources/GeoLogger/Utils/FileManager+Extensions.swift`:

```swift
import Foundation

extension FileManager {
    /// Get or create the GeoLogger directory
    /// - Parameter customDirectory: Optional custom directory, defaults to Documents/GeoLogger
    /// - Returns: URL of the directory
    func geoLoggerDirectory(customDirectory: URL?) throws -> URL {
        let directory: URL

        if let customDirectory = customDirectory {
            directory = customDirectory
        } else {
            let documentsDirectory = try self.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directory = documentsDirectory.appendingPathComponent("GeoLogger", isDirectory: true)
        }

        // Create directory if it doesn't exist
        if !fileExists(atPath: directory.path) {
            try createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    /// Generate a unique recording file name with timestamp
    static func generateRecordingFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.timeZone = TimeZone.current
        let timestamp = formatter.string(from: Date())
        return "geo_log_\(timestamp).json"
    }
}
```

**Step 5: Run test to verify pass**

Run: `swift test --filter FileManagerExtensionsTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/GeoLogger/Utils/FileManager+Extensions.swift Tests/GeoLoggerTests/Utils/FileManagerExtensionsTests.swift
git commit -m "feat: add FileManager extensions for directory management"
```

---

## Phase 6: Recording Session

### Task 9: RecordingSession Structure

**Files:**
- Create: `Sources/GeoLogger/Recording/RecordingSession.swift`
- Create: `Tests/GeoLoggerTests/Recording/RecordingSessionTests.swift`

**Step 1: Create directory**

```bash
mkdir -p Sources/GeoLogger/Recording
mkdir -p Tests/GeoLoggerTests/Recording
```

**Step 2: Write failing test**

Create `Tests/GeoLoggerTests/Recording/RecordingSessionTests.swift`:

```swift
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
```

**Step 3: Run test to verify failure**

Run: `swift test --filter RecordingSessionTests`
Expected: FAIL with "Cannot find 'RecordingSession' in scope"

**Step 4: Implement RecordingSession (basic structure)**

Create `Sources/GeoLogger/Recording/RecordingSession.swift`:

```swift
import Foundation
import CoreLocation

/// Manages recording of location events to JSON file
final class RecordingSession {
    private let directory: URL
    private let queue = DispatchQueue(label: "com.geologist.recording", qos: .utility)

    private var events: [GeoEvent] = []
    private var startTime: Date?
    private var fileName: String?

    private(set) var isRecording = false

    init(directory: URL) throws {
        self.directory = directory
    }

    func start() throws {
        guard !isRecording else { return }

        queue.sync {
            self.startTime = Date()
            self.fileName = FileManager.generateRecordingFileName()
            self.events = []
            self.isRecording = true
        }
    }

    func stop() throws {
        guard isRecording else { return }

        try queue.sync {
            self.isRecording = false
            try self.flush(finalize: true)
        }
    }

    func recordLocation(_ location: CLLocation) {
        guard isRecording, let startTime = startTime else { return }

        queue.async {
            let relativeTime = location.timestamp.timeIntervalSince(startTime)
            let event = GeoEvent.location(
                timestamp: location.timestamp,
                relativeTime: relativeTime,
                location: location
            )
            self.events.append(event)

            // Flush every 10 events
            if self.events.count % 10 == 0 {
                try? self.flush(finalize: false)
            }
        }
    }

    func recordError(_ error: Error) {
        guard isRecording, let startTime = startTime else { return }

        queue.async {
            let now = Date()
            let relativeTime = now.timeIntervalSince(startTime)
            let event = GeoEvent.error(
                timestamp: now,
                relativeTime: relativeTime,
                error: error
            )
            self.events.append(event)
        }
    }

    private func flush(finalize: Bool) throws {
        guard let fileName = fileName, let startTime = startTime else { return }

        let fileURL = directory.appendingPathComponent(fileName)

        let duration = Date().timeIntervalSince(startTime)
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: startTime,
            device: self.deviceModel(),
            systemVersion: self.systemVersion(),
            duration: duration,
            eventCount: events.count
        )

        let recordingFile = RecordingFile(metadata: metadata, events: events)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(recordingFile)
        try data.write(to: fileURL, options: .atomic)
    }

    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        return machine
    }

    private func systemVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "iOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
```

**Step 5: Run test to verify pass**

Run: `swift test --filter RecordingSessionTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/GeoLogger/Recording/RecordingSession.swift Tests/GeoLoggerTests/Recording/RecordingSessionTests.swift
git commit -m "feat: add RecordingSession with start/stop/record"
```

---

### Task 10: RecordingSession Location Recording Test

**Files:**
- Modify: `Tests/GeoLoggerTests/Recording/RecordingSessionTests.swift`

**Step 1: Write failing test**

Add to `Tests/GeoLoggerTests/Recording/RecordingSessionTests.swift`:

```swift
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
```

**Step 2: Run test to verify pass**

Run: `swift test --filter RecordingSessionTests/testRecordLocation`
Expected: PASS (implementation already supports this)

**Step 3: Commit**

```bash
git add Tests/GeoLoggerTests/Recording/RecordingSessionTests.swift
git commit -m "test: add location recording test"
```

---

## Phase 7: Replay Session

### Task 11: ReplaySession Structure

**Files:**
- Create: `Sources/GeoLogger/Replay/ReplaySession.swift`
- Create: `Tests/GeoLoggerTests/Replay/ReplaySessionTests.swift`

**Step 1: Create directory**

```bash
mkdir -p Sources/GeoLogger/Replay
mkdir -p Tests/GeoLoggerTests/Replay
```

**Step 2: Write failing test**

Create `Tests/GeoLoggerTests/Replay/ReplaySessionTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import GeoLogger

final class ReplaySessionTests: XCTestCase {
    var tempDirectory: URL!
    var testFileURL: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeoLoggerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create test recording file
        testFileURL = tempDirectory.appendingPathComponent("test_recording.json")
        createTestRecording()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func createTestRecording() {
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(),
            device: "Test Device",
            systemVersion: "iOS 17.0",
            duration: 2.0,
            eventCount: 2
        )

        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )

        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7559, longitude: 37.6174),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date().addingTimeInterval(1.0)
        )

        let events = [
            GeoEvent.location(timestamp: Date(), relativeTime: 0.0, location: location1),
            GeoEvent.location(timestamp: Date().addingTimeInterval(1.0), relativeTime: 1.0, location: location2)
        ]

        let file = RecordingFile(metadata: metadata, events: events)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]

        let data = try! encoder.encode(file)
        try! data.write(to: testFileURL)
    }

    func testReplaySessionInitialization() throws {
        let session = try ReplaySession(
            fileURL: testFileURL,
            speedMultiplier: 1.0,
            loop: false
        )

        XCTAssertNotNil(session)
        XCTAssertFalse(session.isReplaying)
    }
}
```

**Step 3: Run test to verify failure**

Run: `swift test --filter ReplaySessionTests`
Expected: FAIL with "Cannot find 'ReplaySession' in scope"

**Step 4: Implement ReplaySession (basic structure)**

Create `Sources/GeoLogger/Replay/ReplaySession.swift`:

```swift
import Foundation
import CoreLocation

/// Manages replay of recorded location events
final class ReplaySession {
    typealias LocationCallback = ([CLLocation]) -> Void
    typealias ErrorCallback = (Error) -> Void

    private let recordingFile: RecordingFile
    private let speedMultiplier: Double
    private let loop: Bool
    private let queue = DispatchQueue(label: "com.geologist.replay", qos: .userInitiated)

    private var currentEventIndex = 0
    private var replayStartTime: Date?
    private(set) var isReplaying = false

    var onLocationUpdate: LocationCallback?
    var onError: ErrorCallback?

    init(fileURL: URL, speedMultiplier: Double, loop: Bool) throws {
        // Load and decode recording file
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.recordingFile = try decoder.decode(RecordingFile.self, from: data)

        self.speedMultiplier = speedMultiplier
        self.loop = loop
    }

    func start() {
        guard !isReplaying else { return }

        queue.async {
            self.isReplaying = true
            self.replayStartTime = Date()
            self.currentEventIndex = 0
            self.scheduleNextEvent()
        }
    }

    func stop() {
        queue.async {
            self.isReplaying = false
        }
    }

    private func scheduleNextEvent() {
        guard isReplaying else { return }
        guard currentEventIndex < recordingFile.events.count else {
            if loop {
                currentEventIndex = 0
                replayStartTime = Date()
                scheduleNextEvent()
            } else {
                isReplaying = false
            }
            return
        }

        let event = recordingFile.events[currentEventIndex]
        let adjustedDelay = self.calculateDelay(for: event)

        queue.asyncAfter(deadline: .now() + adjustedDelay) {
            self.deliverEvent(event)
            self.currentEventIndex += 1
            self.scheduleNextEvent()
        }
    }

    private func calculateDelay(for event: GeoEvent) -> TimeInterval {
        guard let replayStartTime = replayStartTime else { return 0 }

        let relativeTime: TimeInterval
        switch event {
        case .location(_, let rt, _):
            relativeTime = rt
        case .error(_, let rt, _):
            relativeTime = rt
        }

        let adjustedRelativeTime = relativeTime / speedMultiplier
        let targetTime = replayStartTime.addingTimeInterval(adjustedRelativeTime)
        let delay = targetTime.timeIntervalSinceNow

        return max(0, delay)
    }

    private func deliverEvent(_ event: GeoEvent) {
        DispatchQueue.main.async {
            switch event {
            case .location(_, _, let location):
                self.onLocationUpdate?([location])
            case .error(_, _, let error):
                self.onError?(error)
            }
        }
    }
}
```

**Step 5: Run test to verify pass**

Run: `swift test --filter ReplaySessionTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/GeoLogger/Replay/ReplaySession.swift Tests/GeoLoggerTests/Replay/ReplaySessionTests.swift
git commit -m "feat: add ReplaySession with timing control"
```

---

### Task 12: ReplaySession Playback Test

**Files:**
- Modify: `Tests/GeoLoggerTests/Replay/ReplaySessionTests.swift`

**Step 1: Write test**

Add to `Tests/GeoLoggerTests/Replay/ReplaySessionTests.swift`:

```swift
func testReplayPlayback() throws {
    let session = try ReplaySession(
        fileURL: testFileURL,
        speedMultiplier: 10.0, // 10x speed for fast test
        loop: false
    )

    let expectation = XCTestExpectation(description: "Received location updates")
    var receivedLocations: [CLLocation] = []

    session.onLocationUpdate = { locations in
        receivedLocations.append(contentsOf: locations)
        if receivedLocations.count >= 2 {
            expectation.fulfill()
        }
    }

    session.start()

    wait(for: [expectation], timeout: 5.0)

    XCTAssertEqual(receivedLocations.count, 2)
    XCTAssertEqual(receivedLocations[0].coordinate.latitude, 55.7558, accuracy: 0.0001)
    XCTAssertEqual(receivedLocations[1].coordinate.latitude, 55.7559, accuracy: 0.0001)
}
```

**Step 2: Run test to verify pass**

Run: `swift test --filter ReplaySessionTests/testReplayPlayback`
Expected: PASS

**Step 3: Commit**

```bash
git add Tests/GeoLoggerTests/Replay/ReplaySessionTests.swift
git commit -m "test: add replay playback test"
```

---

## Phase 8: GeoLogger Delegate

### Task 13: GeoLoggerDelegate Protocol

**Files:**
- Create: `Sources/GeoLogger/GeoLoggerDelegate.swift`
- Create: `Tests/GeoLoggerTests/GeoLoggerDelegateTests.swift`

**Step 1: Write test**

Create `Tests/GeoLoggerTests/GeoLoggerDelegateTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import GeoLogger

final class GeoLoggerDelegateTests: XCTestCase {
    class TestDelegate: GeoLoggerDelegate {
        var locations: [CLLocation] = []
        var errors: [Error] = []

        func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {
            self.locations.append(contentsOf: locations)
        }

        func geoLogger(_ logger: GeoLogger, didFailWithError error: Error) {
            self.errors.append(error)
        }
    }

    func testDelegateConformance() {
        let delegate = TestDelegate()

        XCTAssertNotNil(delegate)
        XCTAssertEqual(delegate.locations.count, 0)
        XCTAssertEqual(delegate.errors.count, 0)
    }
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter GeoLoggerDelegateTests`
Expected: FAIL with "Cannot find 'GeoLoggerDelegate' in scope"

**Step 3: Implement GeoLoggerDelegate**

Create `Sources/GeoLogger/GeoLoggerDelegate.swift`:

```swift
import Foundation
import CoreLocation

/// Delegate protocol for GeoLogger events (mirrors CLLocationManagerDelegate)
public protocol GeoLoggerDelegate: AnyObject {
    /// Called when new locations are available
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation])

    /// Called when location manager fails with error
    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error)
}

// Make delegate methods optional
public extension GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {}
    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error) {}
}
```

**Step 4: Add forward declaration for GeoLogger**

Add to top of `Sources/GeoLogger/GeoLoggerDelegate.swift` after imports:

```swift
// Forward declaration
public class GeoLogger {}
```

**Step 5: Run test to verify pass**

Run: `swift test --filter GeoLoggerDelegateTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/GeoLogger/GeoLoggerDelegate.swift Tests/GeoLoggerTests/GeoLoggerDelegateTests.swift
git commit -m "feat: add GeoLoggerDelegate protocol"
```

---

## Phase 9: GeoLogger Main Class

### Task 14: GeoLogger Structure

**Files:**
- Create: `Sources/GeoLogger/GeoLogger.swift`
- Create: `Tests/GeoLoggerTests/GeoLoggerTests.swift`
- Modify: `Sources/GeoLogger/GeoLoggerDelegate.swift` (remove forward declaration)

**Step 1: Write failing test**

Create `Tests/GeoLoggerTests/GeoLoggerTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import GeoLogger

final class GeoLoggerTests: XCTestCase {
    func testInitialization() {
        let config = GeoLoggerConfiguration()
        let logger = GeoLogger(configuration: config)

        XCTAssertNotNil(logger)
    }

    func testPassthroughMode() {
        var config = GeoLoggerConfiguration()
        config.mode = .passthrough

        let logger = GeoLogger(configuration: config)
        logger.startUpdatingLocation()
        logger.stopUpdatingLocation()

        // Should not crash
        XCTAssertNotNil(logger)
    }
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter GeoLoggerTests`
Expected: FAIL with "Cannot find 'GeoLogger' in scope" (the real one, not forward declaration)

**Step 3: Remove forward declaration**

Edit `Sources/GeoLogger/GeoLoggerDelegate.swift` and remove:

```swift
// Forward declaration
public class GeoLogger {}
```

**Step 4: Implement GeoLogger (basic structure)**

Create `Sources/GeoLogger/GeoLogger.swift`:

```swift
import Foundation
import CoreLocation

/// Main class that wraps CLLocationManager with recording/replay capabilities
public final class GeoLogger: NSObject {
    private let configuration: GeoLoggerConfiguration
    private var locationManager: CLLocationManager?
    private var recordingSession: RecordingSession?
    private var replaySession: ReplaySession?

    /// Delegate for location updates and errors
    public weak var delegate: GeoLoggerDelegate?

    /// Initialize with configuration
    public init(configuration: GeoLoggerConfiguration) {
        self.configuration = configuration
        super.init()

        setupForMode()
    }

    private func setupForMode() {
        switch configuration.mode {
        case .record:
            setupRecordMode()
        case .replay:
            setupReplayMode()
        case .passthrough:
            setupPassthroughMode()
        }
    }

    private func setupRecordMode() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self

        do {
            let directory = try FileManager.default.geoLoggerDirectory(
                customDirectory: configuration.directory
            )
            recordingSession = try RecordingSession(directory: directory)
        } catch {
            print("GeoLogger: Failed to setup recording session: \(error)")
        }
    }

    private func setupReplayMode() {
        guard let fileName = configuration.replayFileName else {
            print("GeoLogger: Replay mode requires replayFileName")
            return
        }

        do {
            let directory = try FileManager.default.geoLoggerDirectory(
                customDirectory: configuration.directory
            )
            let fileURL = directory.appendingPathComponent(fileName)

            replaySession = try ReplaySession(
                fileURL: fileURL,
                speedMultiplier: configuration.replaySpeedMultiplier,
                loop: configuration.loopReplay
            )

            replaySession?.onLocationUpdate = { [weak self] locations in
                guard let self = self else { return }
                self.delegate?.geoLogger(self, didUpdateLocations: locations)
            }

            replaySession?.onError = { [weak self] error in
                guard let self = self else { return }
                self.delegate?.geoLogger(self, didFailWithError: error)
            }
        } catch {
            delegate?.geoLogger(self, didFailWithError: error)
        }
    }

    private func setupPassthroughMode() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
    }

    // MARK: - Public API (mirrors CLLocationManager)

    public func requestWhenInUseAuthorization() {
        locationManager?.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        locationManager?.requestAlwaysAuthorization()
    }

    public func startUpdatingLocation() {
        switch configuration.mode {
        case .record:
            try? recordingSession?.start()
            locationManager?.startUpdatingLocation()
        case .replay:
            replaySession?.start()
        case .passthrough:
            locationManager?.startUpdatingLocation()
        }
    }

    public func stopUpdatingLocation() {
        switch configuration.mode {
        case .record:
            try? recordingSession?.stop()
            locationManager?.stopUpdatingLocation()
        case .replay:
            replaySession?.stop()
        case .passthrough:
            locationManager?.stopUpdatingLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension GeoLogger: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Record if in record mode
        if configuration.mode == .record {
            locations.forEach { recordingSession?.recordLocation($0) }
        }

        // Forward to delegate
        delegate?.geoLogger(self, didUpdateLocations: locations)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Record if in record mode
        if configuration.mode == .record {
            recordingSession?.recordError(error)
        }

        // Forward to delegate
        delegate?.geoLogger(self, didFailWithError: error)
    }
}
```

**Step 5: Run test to verify pass**

Run: `swift test --filter GeoLoggerTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/GeoLogger/GeoLogger.swift Sources/GeoLogger/GeoLoggerDelegate.swift Tests/GeoLoggerTests/GeoLoggerTests.swift
git commit -m "feat: add GeoLogger main class with mode switching"
```

---

## Phase 10: Recording Manager

### Task 15: RecordingManager Implementation

**Files:**
- Create: `Sources/GeoLogger/Recording/RecordingManager.swift`
- Create: `Tests/GeoLoggerTests/Recording/RecordingManagerTests.swift`

**Step 1: Write failing test**

Create `Tests/GeoLoggerTests/Recording/RecordingManagerTests.swift`:

```swift
import XCTest
@testable import GeoLogger

final class RecordingManagerTests: XCTestCase {
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

    func testListRecordings() throws {
        let manager = RecordingManager(directory: tempDirectory)

        // Create test file
        let testFile = tempDirectory.appendingPathComponent("geo_log_2026-01-05_14-30-00.json")
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: Date(),
            device: "Test",
            systemVersion: "iOS 17",
            duration: 100,
            eventCount: 10
        )
        let file = RecordingFile(metadata: metadata, events: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        try data.write(to: testFile)

        let recordings = manager.listRecordings()

        XCTAssertEqual(recordings.count, 1)
        XCTAssertEqual(recordings[0].name, "geo_log_2026-01-05_14-30-00.json")
        XCTAssertEqual(recordings[0].duration, 100, accuracy: 0.01)
        XCTAssertEqual(recordings[0].eventCount, 10)
    }

    func testDeleteRecording() throws {
        let manager = RecordingManager(directory: tempDirectory)

        // Create test file
        let testFile = tempDirectory.appendingPathComponent("test.json")
        try "{}".write(to: testFile, atomically: true, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        try manager.deleteRecording(name: "test.json")

        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))
    }

    func testExportRecording() throws {
        let manager = RecordingManager(directory: tempDirectory)

        // Create test file
        let testFile = tempDirectory.appendingPathComponent("test.json")
        try "{}".write(to: testFile, atomically: true, encoding: .utf8)

        let exportURL = manager.exportRecording(name: "test.json")

        XCTAssertEqual(exportURL, testFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
    }
}
```

**Step 2: Run test to verify failure**

Run: `swift test --filter RecordingManagerTests`
Expected: FAIL with "Cannot find 'RecordingManager' in scope"

**Step 3: Implement RecordingManager**

Create `Sources/GeoLogger/Recording/RecordingManager.swift`:

```swift
import Foundation

/// Manages recording files (list, delete, export)
public final class RecordingManager {
    private let directory: URL

    /// Shared instance using default directory
    public static let shared = RecordingManager(directory: nil)

    /// Initialize with custom directory
    public init(directory: URL?) {
        if let directory = directory {
            self.directory = directory
        } else {
            self.directory = (try? FileManager.default.geoLoggerDirectory(customDirectory: nil))
                ?? FileManager.default.temporaryDirectory
        }
    }

    /// List all recordings in directory
    public func listRecordings() -> [RecordingInfo] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { fileURL -> RecordingInfo? in
                guard let data = try? Data(contentsOf: fileURL),
                      let recordingFile = try? self.decodeRecordingFile(data),
                      let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                      let size = attributes[.size] as? Int64,
                      let creationDate = attributes[.creationDate] as? Date else {
                    return nil
                }

                return RecordingInfo(
                    name: fileURL.lastPathComponent,
                    date: creationDate,
                    size: size,
                    duration: recordingFile.metadata.duration,
                    eventCount: recordingFile.metadata.eventCount
                )
            }
            .sorted { $0.date > $1.date }
    }

    /// Delete a recording by name
    public func deleteRecording(name: String) throws {
        let fileURL = directory.appendingPathComponent(name)
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Get URL for sharing/exporting recording
    public func exportRecording(name: String) -> URL {
        return directory.appendingPathComponent(name)
    }

    private func decodeRecordingFile(_ data: Data) throws -> RecordingFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RecordingFile.self, from: data)
    }
}
```

**Step 4: Run test to verify pass**

Run: `swift test --filter RecordingManagerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/GeoLogger/Recording/RecordingManager.swift Tests/GeoLoggerTests/Recording/RecordingManagerTests.swift
git commit -m "feat: add RecordingManager for file operations"
```

---

## Phase 11: Integration Testing

### Task 16: End-to-End Record and Replay Test

**Files:**
- Create: `Tests/GeoLoggerTests/Integration/EndToEndTests.swift`

**Step 1: Create directory**

```bash
mkdir -p Tests/GeoLoggerTests/Integration
```

**Step 2: Write test**

Create `Tests/GeoLoggerTests/Integration/EndToEndTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import GeoLogger

final class EndToEndTests: XCTestCase {
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

    func testRecordAndReplay() throws {
        // Step 1: Record
        var recordConfig = GeoLoggerConfiguration()
        recordConfig.mode = .record
        recordConfig.directory = tempDirectory

        let recordLogger = GeoLogger(configuration: recordConfig)

        class RecordDelegate: GeoLoggerDelegate {
            var locations: [CLLocation] = []

            func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {
                self.locations.append(contentsOf: locations)
            }
        }

        let recordDelegate = RecordDelegate()
        recordLogger.delegate = recordDelegate
        recordLogger.startUpdatingLocation()

        // Simulate location updates
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date()
        )

        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 55.7559, longitude: 37.6174),
            altitude: 150.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 10.0,
            timestamp: Date().addingTimeInterval(1.0)
        )

        // Manually trigger delegate (in real scenario CLLocationManager would call this)
        recordLogger.delegate?.geoLogger(recordLogger, didUpdateLocations: [location1])
        Thread.sleep(forTimeInterval: 0.1)
        recordLogger.delegate?.geoLogger(recordLogger, didUpdateLocations: [location2])
        Thread.sleep(forTimeInterval: 0.1)

        recordLogger.stopUpdatingLocation()

        // Give time for async file write
        Thread.sleep(forTimeInterval: 0.5)

        // Step 2: Verify recording file exists
        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "Should have created one recording file")

        let recordingFileName = files[0].lastPathComponent

        // Step 3: Replay
        var replayConfig = GeoLoggerConfiguration()
        replayConfig.mode = .replay
        replayConfig.directory = tempDirectory
        replayConfig.replayFileName = recordingFileName
        replayConfig.replaySpeedMultiplier = 10.0

        let replayLogger = GeoLogger(configuration: replayConfig)

        class ReplayDelegate: GeoLoggerDelegate {
            let expectation: XCTestExpectation
            var locations: [CLLocation] = []

            init(expectation: XCTestExpectation) {
                self.expectation = expectation
            }

            func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {
                self.locations.append(contentsOf: locations)
                if self.locations.count >= 2 {
                    expectation.fulfill()
                }
            }
        }

        let expectation = XCTestExpectation(description: "Replay locations")
        let replayDelegate = ReplayDelegate(expectation: expectation)
        replayLogger.delegate = replayDelegate

        replayLogger.startUpdatingLocation()

        wait(for: [expectation], timeout: 5.0)

        // Verify replayed locations match recorded ones
        XCTAssertEqual(replayDelegate.locations.count, 2)
        XCTAssertEqual(replayDelegate.locations[0].coordinate.latitude, 55.7558, accuracy: 0.0001)
        XCTAssertEqual(replayDelegate.locations[1].coordinate.latitude, 55.7559, accuracy: 0.0001)
    }
}
```

**Step 3: Run test**

Run: `swift test --filter EndToEndTests`
Expected: PASS

**Step 4: Commit**

```bash
git add Tests/GeoLoggerTests/Integration/EndToEndTests.swift
git commit -m "test: add end-to-end record and replay integration test"
```

---

## Phase 12: Documentation

### Task 17: README

**Files:**
- Create: `README.md`

**Step 1: Write README**

Create `README.md`:

```markdown
# GeoLogger

iOS SDK for recording and replaying CLLocationManager geodata for debugging purposes.

## Features

- 📍 Record location updates and errors to JSON files
- ▶️ Replay recorded routes with accurate timing
- ⚡️ Speed multiplier for faster replay (2x, 10x, etc.)
- 📤 Share recordings between devices
- 🔄 Minimal integration - replace CLLocationManager with GeoLogger
- 💾 Automatic file management with timestamp-based naming
- 📊 Full CLLocation data capture

## Installation

### Swift Package Manager

Add GeoLogger to your project via Xcode:

1. File → Add Package Dependencies
2. Enter repository URL
3. Select version

Or add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/GeoLogger.git", from: "1.0.0")
]
```

## Quick Start

### Recording

```swift
import GeoLogger

// Configure for recording
var config = GeoLoggerConfiguration()
config.mode = .record

// Use like CLLocationManager
let geoLogger = GeoLogger(configuration: config)
geoLogger.delegate = self
geoLogger.requestWhenInUseAuthorization()
geoLogger.startUpdatingLocation()

// Stop recording
geoLogger.stopUpdatingLocation()
```

### Replay

```swift
// Configure for replay
var config = GeoLoggerConfiguration()
config.mode = .replay
config.replayFileName = "geo_log_2026-01-05_14-30-00.json"
config.replaySpeedMultiplier = 2.0 // 2x speed

let geoLogger = GeoLogger(configuration: config)
geoLogger.delegate = self
geoLogger.startUpdatingLocation() // begins replay
```

### Managing Recordings

```swift
// List recordings
let recordings = RecordingManager.shared.listRecordings()
for recording in recordings {
    print("\(recording.name) - \(recording.duration)s - \(recording.eventCount) events")
}

// Export for sharing
let url = RecordingManager.shared.exportRecording(name: "geo_log_2026-01-05_14-30-00.json")
let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
present(activityVC, animated: true)

// Delete recording
try RecordingManager.shared.deleteRecording(name: "geo_log_2026-01-05_14-30-00.json")
```

## Configuration Options

```swift
var config = GeoLoggerConfiguration()

// Mode: .record, .replay, or .passthrough
config.mode = .record

// Custom directory (default: Documents/GeoLogger)
config.directory = customURL

// Replay speed multiplier (default: 1.0)
config.replaySpeedMultiplier = 2.0

// Replay file name (required for replay mode)
config.replayFileName = "recording.json"

// Loop replay when it ends (default: false)
config.loopReplay = true
```

## Delegate

Implements the same pattern as `CLLocationManagerDelegate`:

```swift
extension MyViewController: GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates
    }

    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error) {
        // Handle errors
    }
}
```

## File Format

Recordings are stored as JSON files with full CLLocation data:

```json
{
  "metadata": {
    "version": "1.0",
    "recordedAt": "2026-01-05T14:30:00Z",
    "device": "iPhone 15 Pro",
    "systemVersion": "iOS 17.2",
    "duration": 3600.5,
    "eventCount": 245
  },
  "events": [
    {
      "type": "location",
      "timestamp": "2026-01-05T14:30:01Z",
      "relativeTime": 1.0,
      "data": { ... }
    }
  ]
}
```

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## Privacy

Recording files contain sensitive location data. Remember to:

- Never commit recordings to public repositories
- Add `*.json` to .gitignore for recording directories
- Inform testers about location data in shared files

## License

MIT License - see LICENSE file

## Contributing

Contributions welcome! Please open an issue or pull request.
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add comprehensive README"
```

---

### Task 18: CHANGELOG

**Files:**
- Create: `CHANGELOG.md`

**Step 1: Write CHANGELOG**

Create `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to GeoLogger will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-05

### Added
- Initial release of GeoLogger iOS SDK
- Record mode: Record CLLocationManager updates to JSON files
- Replay mode: Replay recorded routes with accurate timing
- Passthrough mode: Use as regular CLLocationManager
- Speed multiplier for replay (accelerate/decelerate playback)
- RecordingManager for file operations (list, delete, export)
- Automatic timestamp-based file naming
- Full CLLocation data serialization
- Device and system metadata in recordings
- Loop replay option
- Thread-safe implementation with background processing
- Swift Package Manager support
- Comprehensive test suite
- Documentation and examples

### Supported
- iOS 14.0+
- Swift 5.9+
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add CHANGELOG for v1.0.0"
```

---

### Task 19: Example App (Optional)

**Files:**
- Create: `Examples/GeoLoggerExample/GeoLoggerExample.xcodeproj`
- Create: `Examples/GeoLoggerExample/Sources/AppDelegate.swift`
- Create: `Examples/GeoLoggerExample/Sources/ViewController.swift`

**Note:** Creating a full example Xcode project is complex in this format. Instead, we'll create a simple Swift file demonstrating usage.

**Step 1: Create example directory**

```bash
mkdir -p Examples/GeoLoggerExample/Sources
```

**Step 2: Write example code**

Create `Examples/GeoLoggerExample/Sources/ExampleUsage.swift`:

```swift
import UIKit
import CoreLocation
import GeoLogger

class LocationViewController: UIViewController {
    var geoLogger: GeoLogger!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGeoLogger()
    }

    func setupGeoLogger() {
        // For recording
        var config = GeoLoggerConfiguration()
        config.mode = .record

        geoLogger = GeoLogger(configuration: config)
        geoLogger.delegate = self
        geoLogger.requestWhenInUseAuthorization()
    }

    @IBAction func startRecording(_ sender: UIButton) {
        geoLogger.startUpdatingLocation()
    }

    @IBAction func stopRecording(_ sender: UIButton) {
        geoLogger.stopUpdatingLocation()
    }

    @IBAction func listRecordings(_ sender: UIButton) {
        let recordings = RecordingManager.shared.listRecordings()
        recordings.forEach { recording in
            print("\(recording.name)")
            print("  Duration: \(recording.duration)s")
            print("  Events: \(recording.eventCount)")
            print("  Size: \(recording.size) bytes")
        }
    }

    @IBAction func shareRecording(_ sender: UIButton) {
        guard let firstRecording = RecordingManager.shared.listRecordings().first else {
            return
        }

        let url = RecordingManager.shared.exportRecording(name: firstRecording.name)
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        present(activityVC, animated: true)
    }

    func playbackRecording(fileName: String) {
        var config = GeoLoggerConfiguration()
        config.mode = .replay
        config.replayFileName = fileName
        config.replaySpeedMultiplier = 1.0
        config.loopReplay = false

        geoLogger = GeoLogger(configuration: config)
        geoLogger.delegate = self
        geoLogger.startUpdatingLocation()
    }
}

extension LocationViewController: GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        print("Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("Accuracy: \(location.horizontalAccuracy)m")
        print("Speed: \(location.speed)m/s")

        // Update UI with location
    }

    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")

        // Show error to user
    }
}
```

**Step 3: Commit**

```bash
git add Examples/
git commit -m "docs: add example usage code"
```

---

## Phase 13: Final Testing and Verification

### Task 20: Run Full Test Suite

**Step 1: Run all tests**

Run: `swift test`
Expected: All tests PASS

**Step 2: Check test coverage (if available)**

Run: `swift test --enable-code-coverage`

**Step 3: Build package**

Run: `swift build -c release`
Expected: Build succeeds

**Step 4: Commit if any fixes needed**

```bash
git add .
git commit -m "fix: address test failures and build issues"
```

---

### Task 21: Final Package Verification

**Step 1: Verify Package.swift is correct**

Run: `swift package dump-package`
Expected: Valid JSON output

**Step 2: Verify all public APIs are accessible**

Create temporary test file to verify imports work correctly.

**Step 3: Create git tag for v1.0.0**

```bash
git tag -a v1.0.0 -m "GeoLogger v1.0.0 - Initial release"
```

**Step 4: Final commit**

```bash
git add .
git commit -m "release: GeoLogger v1.0.0"
```

---

## Completion Checklist

- [ ] SPM package structure created
- [ ] All models implemented (Configuration, Metadata, Event, RecordingInfo)
- [ ] JSON serialization working correctly
- [ ] RecordingSession with file writing
- [ ] ReplaySession with timing control
- [ ] GeoLogger main class with mode switching
- [ ] RecordingManager for file operations
- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] README documentation
- [ ] CHANGELOG created
- [ ] Example usage code
- [ ] Package builds successfully
- [ ] Git tag created

## Notes

- All file writes happen on background queue to avoid UI blocking
- Delegate callbacks always delivered on main thread
- Thread-safety guaranteed by serial queues
- JSON format versioned for future compatibility
- Error handling with graceful fallbacks
- Minimal dependencies (only CoreLocation + Foundation)

## Next Steps After Implementation

1. Test on real device with GPS
2. Profile memory usage with long recordings
3. Test with various iOS versions (14.0 - latest)
4. Consider adding Combine publishers in future version
5. Add visual documentation with diagrams
6. Create video tutorial
7. Submit to Swift Package Index
