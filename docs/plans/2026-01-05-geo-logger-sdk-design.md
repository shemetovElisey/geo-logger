# GeoLogger iOS SDK - Design Document

**Date:** 2026-01-05
**Version:** 1.0
**Purpose:** SDK for logging and replaying CLLocationManager geodata for debugging purposes

## Overview

GeoLogger is an iOS SDK that wraps CLLocationManager to enable recording GPS routes to JSON files and replaying them with accurate timing. This allows developers to reproduce exact routes during debugging without needing to physically travel or simulate locations manually.

## Key Features

- Record CLLocation updates and errors to JSON files
- Replay recorded routes with real-time timing and speed multiplier
- Share recordings between devices for team debugging
- Minimal integration (replace CLLocationManager with GeoLogger)
- Automatic file management with timestamp-based naming
- Full CLLocation data capture for maximum accuracy

## Architecture

### Core Components

#### 1. GeoLogger (Main Class)

The primary interface that wraps CLLocationManager and manages three operational modes:

- **Record Mode**: Intercepts all location updates and errors, writes to JSON
- **Replay Mode**: Reads JSON and reproduces events with accurate timing
- **Passthrough Mode**: Acts as regular CLLocationManager without logging

The API closely mirrors CLLocationManager. Developers replace `CLLocationManager()` with `GeoLogger(configuration: config)` and use the same delegate pattern.

#### 2. GeoLoggerConfiguration

Configuration struct with settings:

```swift
struct GeoLoggerConfiguration {
    var mode: GeoLoggerMode = .passthrough
    var directory: URL? = nil // defaults to Documents directory
    var replaySpeedMultiplier: Double = 1.0
    var replayFileName: String? = nil
    var loopReplay: Bool = false
}

enum GeoLoggerMode {
    case record
    case replay
    case passthrough
}
```

#### 3. RecordingSession

Handles recording operations:
- Listens to CLLocationManager delegate callbacks
- Buffers events in memory
- Flushes to JSON file periodically (every 10 events or 30 seconds)
- Finalizes file with metadata when recording stops

#### 4. ReplaySession

Handles playback operations:
- Loads JSON into memory on start
- Uses DispatchQueue with asyncAfter for timing
- Applies speedMultiplier to relativeTime intervals
- Invokes delegate callbacks on main thread

#### 5. RecordingManager

Manages recorded files:

```swift
class RecordingManager {
    static let shared = RecordingManager()

    func listRecordings() -> [RecordingInfo]
    func deleteRecording(name: String) throws
    func exportRecording(name: String) -> URL
}

struct RecordingInfo {
    let name: String
    let date: Date
    let size: Int64
    let duration: TimeInterval
    let eventCount: Int
}
```

## JSON File Format

### Structure

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
      "data": {
        "coordinate": {
          "latitude": 55.7558,
          "longitude": 37.6173
        },
        "altitude": 150.5,
        "horizontalAccuracy": 10.0,
        "verticalAccuracy": 15.0,
        "course": 180.0,
        "courseAccuracy": 5.0,
        "speed": 1.5,
        "speedAccuracy": 0.5,
        "floor": 0,
        "timestamp": "2026-01-05T14:30:01Z",
        "ellipsoidalAltitude": 151.2,
        "sourceInformation": {
          "isSimulatedBySoftware": false,
          "isProducedByAccessory": false
        }
      }
    },
    {
      "type": "error",
      "timestamp": "2026-01-05T14:32:15Z",
      "relativeTime": 135.0,
      "code": 0,
      "domain": "kCLErrorDomain",
      "description": "Location services denied"
    }
  ]
}
```

### Key Design Decisions

- **relativeTime**: Seconds from recording start, used for accurate timing reproduction
- **Full CLLocation dump**: All available fields including ellipsoidalAltitude, sourceInformation, etc.
- **Chronological order**: Events ordered by time for accurate replay
- **Metadata**: Device and system info for debugging context
- **Automatic naming**: Files named `geo_log_YYYY-MM-DD_HH-MM-SS.json` to prevent overwrites

## API Usage

### Recording

```swift
// Create configuration
var config = GeoLoggerConfiguration()
config.mode = .record
config.directory = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
).first

// Initialize GeoLogger
let geoLogger = GeoLogger(configuration: config)
geoLogger.delegate = self

// Use like CLLocationManager
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
config.loopReplay = false

let geoLogger = GeoLogger(configuration: config)
geoLogger.delegate = self
geoLogger.startUpdatingLocation() // begins replay
```

### Delegate Implementation

```swift
extension MyViewController: GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger,
                   didUpdateLocations locations: [CLLocation]) {
        // Handle location updates (same as CLLocationManagerDelegate)
    }

    func geoLogger(_ logger: GeoLogger,
                   didFailWithError error: Error) {
        // Handle errors
    }
}
```

### Managing Recordings

```swift
// List all recordings
let recordings = RecordingManager.shared.listRecordings()
for recording in recordings {
    print("\(recording.name) - \(recording.duration)s")
}

// Export for sharing
let url = RecordingManager.shared.exportRecording(
    name: "geo_log_2026-01-05_14-30-00.json"
)
let activityVC = UIActivityViewController(
    activityItems: [url],
    applicationActivities: nil
)
present(activityVC, animated: true)

// Delete recording
try RecordingManager.shared.deleteRecording(
    name: "geo_log_2026-01-05_14-30-00.json"
)
```

## Error Handling

### Recording Errors
- **Insufficient storage**: Stop recording gracefully, save partial data
- **File write failures**: Retry with exponential backoff, log error
- **Permission denied**: Record error event, proxy to delegate

### Replay Errors
- **File not found**: Call `delegate.didFailWithError` immediately
- **Corrupted JSON**: Fallback to passthrough mode, log warning
- **Invalid format**: Same as corrupted JSON

### General
- **Multiple `startUpdatingLocation()` calls**: Ignore subsequent calls
- **Configuration change during operation**: Ignore, require new GeoLogger instance
- **Replay completion**: Stop or loop based on `config.loopReplay`

## Threading Model

**Design principle**: Automatic background processing with main thread callbacks

- **Recording**: File writes happen on background serial queue
- **Replay**: Timing managed on background queue
- **Delegate callbacks**: Always delivered on main thread
- **Thread safety**: All mutable state protected by serial queue
- **No manual queue management**: Transparent to developers

This matches CLLocationManager behavior and prevents UI blocking.

## Project Structure

```
GeoLogger/
├── Package.swift
├── README.md
├── CHANGELOG.md
├── Sources/
│   └── GeoLogger/
│       ├── GeoLogger.swift
│       ├── GeoLoggerConfiguration.swift
│       ├── GeoLoggerDelegate.swift
│       ├── Models/
│       │   ├── RecordingInfo.swift
│       │   ├── GeoEvent.swift
│       │   └── RecordingMetadata.swift
│       ├── Recording/
│       │   ├── RecordingSession.swift
│       │   └── RecordingManager.swift
│       ├── Replay/
│       │   └── ReplaySession.swift
│       └── Utils/
│           ├── JSONSerializer.swift
│           └── FileManager+Extensions.swift
├── Tests/
│   └── GeoLoggerTests/
│       ├── RecordingSessionTests.swift
│       ├── ReplaySessionTests.swift
│       ├── GeoLoggerTests.swift
│       └── Mocks/
│           └── MockCLLocationManager.swift
└── Examples/
    └── GeoLoggerExample/
        └── ... (sample iOS app)
```

## Testing Strategy

### Unit Tests

**RecordingSession:**
- CLLocation serialization (all fields captured correctly)
- Periodic flush mechanism
- Metadata generation (duration, eventCount accuracy)
- Error handling during write operations

**ReplaySession:**
- JSON deserialization accuracy
- Timing precision (events arrive at correct intervals)
- Speed multiplier correctness (2x = half time between events)
- Corrupted JSON handling

**GeoLogger:**
- Mode switching behavior
- Delegate callback proxying
- Thread safety under concurrent calls

### Integration Tests

- End-to-end record → replay cycle
- Export → import workflow (simulating device transfer)
- Long recordings with 1000+ events
- Memory usage under sustained recording

### Mock Objects

- **MockCLLocationManager**: Test without real GPS
- **MockFileManager**: Test file operations without disk I/O

## Distribution

### Swift Package Manager

**Package.swift:**

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

**Integration:**

```swift
// In Xcode: File → Add Package Dependencies
// Enter repository URL
// Select version

import GeoLogger
```

### Versioning

- Semantic versioning: MAJOR.MINOR.PATCH
- Git tags for releases
- CHANGELOG.md tracking all changes
- Breaking changes only in major versions

## Privacy & Permissions

SDK requires same permissions as CLLocationManager. Developers must add to Info.plist:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>App needs location for [purpose]</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>App needs background location for [purpose]</string>
```

Recording files contain sensitive location data. Developers should:
- Never commit recordings to public repositories
- Add `*.json` to .gitignore for recording directory
- Inform testers about location data in shared files

## Documentation

### README.md

- Quick start guide
- Installation instructions
- Basic usage examples
- Link to full documentation

### DocC Documentation

- Public API reference with examples
- Guides for common workflows
- Troubleshooting section

### Inline Documentation

- Complex timing logic in ReplaySession
- Threading guarantees in critical sections
- File format versioning strategy

## Future Enhancements (Out of Scope)

Not included in v1.0 but potential future additions:

- Cloud sync for recordings
- Visual route preview/editor
- Network request recording alongside location
- Sensor data recording (accelerometer, gyroscope)
- Background location recording support
- Multiple delegate support
- Combine/Async publishers

## Success Criteria

SDK is successful if:

1. Developers can record a route in < 5 minutes of setup
2. Recorded routes replay with < 100ms timing accuracy
3. Files can be shared and imported without manual editing
4. Integration requires changing only 2-3 lines of code
5. No performance impact in passthrough mode
6. Zero crashes in production usage

## Implementation Plan

Implementation will proceed in phases:

1. **Core Infrastructure** (RecordingSession, ReplaySession, JSON serialization)
2. **GeoLogger Wrapper** (Mode switching, delegate proxying)
3. **RecordingManager** (File operations, listing, export)
4. **Threading & Performance** (Background queues, buffering)
5. **Testing** (Unit tests, integration tests, mocks)
6. **Documentation** (README, DocC, examples)
7. **SPM Package** (Package.swift, versioning, release)

Each phase should be completed and tested before moving to the next.
