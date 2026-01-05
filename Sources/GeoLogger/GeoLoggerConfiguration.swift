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
