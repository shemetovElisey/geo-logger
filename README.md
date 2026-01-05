# GeoLogger

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2014+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

GeoLogger is an iOS SDK that wraps `CLLocationManager` with powerful recording and replay capabilities. It enables developers to record real location data during development and replay it later for testing and debugging purposes.

## Features

- 📍 **Record Mode**: Capture real location updates to JSON files
- ▶️ **Replay Mode**: Play back recorded location data with timing control
- 🔄 **Passthrough Mode**: Use as a drop-in replacement for `CLLocationManager`
- 📊 **Progress Tracking**: Monitor replay progress with callbacks
- 📁 **File Management**: List, delete, and export recordings
- 🗺️ **GPX Support**: Export recordings to GPX format and replay GPX files
- ⚡ **Speed Control**: Adjust replay speed with multipliers
- 🔁 **Loop Support**: Automatically loop replay sessions

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add GeoLogger to your project using Swift Package Manager:

1. In Xcode, select **File** → **Add Packages...**
2. Enter the repository URL:
   ```
   https://github.com/shemetovElisey/geo-logger.git
   ```
3. Select the version or branch you want to use
4. Add the `GeoLogger` library to your target

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/shemetovElisey/geo-logger.git", from: "1.0.0")
]
```

## Quick Start

### 1. Import the Framework

```swift
import GeoLogger
import CoreLocation
```

### 2. Configure GeoLogger

```swift
var config = GeoLoggerConfiguration()
config.mode = .record  // or .replay, .passthrough
let geoLogger = GeoLogger(configuration: config)
```

### 3. Set Up Delegates

```swift
class LocationManager: NSObject, CLLocationManagerDelegate, GeoLoggerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle errors
    }
    
    // Optional: Handle replay progress updates
    func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval) {
        print("Replay progress: \(progress * 100)%")
    }
}

let delegate = LocationManager()
geoLogger.locationManagerDelegate = delegate  // For location updates/errors
geoLogger.geoLoggerDelegate = delegate        // For replay progress (optional)
```

### 4. Request Authorization

```swift
geoLogger.requestWhenInUseAuthorization()
```

### 5. Start Location Updates

```swift
geoLogger.startUpdatingLocation()
```

## Usage Examples

### Recording Location Data

```swift
var config = GeoLoggerConfiguration()
config.mode = .record
let geoLogger = GeoLogger(configuration: config)
geoLogger.locationManagerDelegate = self  // Use CLLocationManagerDelegate

geoLogger.requestWhenInUseAuthorization()
geoLogger.startUpdatingLocation()

// Later, stop recording
geoLogger.stopUpdatingLocation()
```

### Replaying Recorded Data

```swift
var config = GeoLoggerConfiguration()
config.mode = .replay
config.replayFileName = "my_recording.json"
config.replaySpeedMultiplier = 2.0  // 2x speed
config.loopReplay = false

let geoLogger = GeoLogger(configuration: config)
geoLogger.locationManagerDelegate = self  // For location updates
geoLogger.geoLoggerDelegate = self        // For progress updates (optional)

geoLogger.startUpdatingLocation()

// Handle location updates via CLLocationManagerDelegate
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Handle locations
}

// Monitor progress via GeoLoggerDelegate (optional)
func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval) {
    print("Progress: \(progress * 100)%")
    print("Current time: \(currentTime)s")
}
```

### Replaying GPX Files

```swift
var config = GeoLoggerConfiguration()
config.mode = .replay
config.replayFileName = "track.gpx"  // GPX file
config.replaySpeedMultiplier = 1.0

let geoLogger = GeoLogger(configuration: config)
geoLogger.locationManagerDelegate = self  // Use CLLocationManagerDelegate
geoLogger.startUpdatingLocation()
```

### Managing Recordings

```swift
let manager = RecordingManager()

// List all recordings
let recordings = try manager.listRecordings()

// Delete a recording
try manager.deleteRecording(name: "my_recording.json")

// Export as JSON
let jsonURL = try manager.exportRecording(name: "my_recording.json")

// Export as GPX
let gpxURL = try manager.exportRecordingAsGPX(name: "my_recording.json", gpxFileName: "my_recording.gpx")
```

### Passthrough Mode

Use GeoLogger as a drop-in replacement for `CLLocationManager`:

```swift
var config = GeoLoggerConfiguration()
config.mode = .passthrough  // No recording or replay
let geoLogger = GeoLogger(configuration: config)
// Use exactly like CLLocationManager
```

## Configuration Options

### GeoLoggerConfiguration

- `mode: GeoLoggerMode` - Operating mode (`.record`, `.replay`, `.passthrough`)
- `directory: URL?` - Custom directory for recordings (defaults to Documents)
- `replayFileName: String?` - File name for replay mode
- `replaySpeedMultiplier: Double` - Speed multiplier for replay (default: 1.0)
- `loopReplay: Bool` - Whether to loop replay when it ends (default: false)

## File Formats

### JSON Format

Recordings are saved as JSON files with the following structure:

```json
{
  "metadata": {
    "version": "1.0",
    "recordedAt": "2026-01-05T12:00:00Z",
    "device": "iPhone 15 Pro",
    "systemVersion": "iOS 17.2",
    "duration": 3600.0,
    "eventCount": 1000
  },
  "events": [
    {
      "type": "location",
      "timestamp": "2026-01-05T12:00:00Z",
      "relativeTime": 0.0,
      "data": {
        "coordinate": {
          "latitude": 55.7558,
          "longitude": 37.6173
        },
        "altitude": 150.0,
        "horizontalAccuracy": 10.0,
        "verticalAccuracy": 10.0,
        "speed": 5.0,
        "course": 90.0,
        "timestamp": "2026-01-05T12:00:00Z"
      }
    }
  ]
}
```

### GPX Format

GeoLogger supports standard GPX 1.1 format for compatibility with GPS applications and tools.

## Demo App

A complete demo application is available in the `Examples/Demo/` directory. It demonstrates:

- Recording location data
- Replaying recordings
- Visualizing routes on a map
- Managing recording files
- Exporting to GPX format

See `Examples/Demo/README.md` for setup instructions.

## API Reference

### GeoLogger

Main class that wraps `CLLocationManager`.

**Methods:**
- `init(configuration: GeoLoggerConfiguration)`
- `requestWhenInUseAuthorization()`
- `requestAlwaysAuthorization()`
- `startUpdatingLocation()`
- `stopUpdatingLocation()`

### GeoLoggerDelegate

Protocol for GeoLogger-specific events (e.g., replay progress).

**Methods:**
- `geoLogger(_:didUpdateReplayProgress:currentTime:)` - Called when replay progress updates

**Note:** For location updates and errors, use `CLLocationManagerDelegate` directly via `locationManagerDelegate` property.

### RecordingManager

Utility for managing recording files.

**Methods:**
- `listRecordings() throws -> [RecordingInfo]`
- `deleteRecording(name:) throws`
- `exportRecording(name:) throws -> URL`
- `exportRecordingAsGPX(name:gpxFileName:) throws -> URL`

## Testing

The SDK includes comprehensive unit and integration tests. Run tests using:

```bash
swift test
```

Or in Xcode: **Product** → **Test** (⌘U)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

GeoLogger is released under the MIT License. See [LICENSE](LICENSE) for details.

## Author

Elisey Shemetov

## Acknowledgments

- Built with Swift and CoreLocation
- Inspired by the need for better location testing tools in iOS development

