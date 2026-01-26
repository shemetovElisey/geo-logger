import Foundation

/// Operating mode for GeoLogger
public enum GeoLoggerMode {
    /// Record location updates to JSON file (uses CoreData as buffer during recording)
    case record
    /// Replay location updates from JSON or GPX file
    case replay
    /// Pass through to real CLLocationManager without logging
    case passthrough
}

/// Configuration for GeoLogger behavior
public struct GeoLoggerConfiguration {
    /// Operating mode (record, replay, or passthrough)
    public var mode: GeoLoggerMode = .passthrough

    /// Directory for storing/reading recordings. Defaults to Documents directory
    public var directory: URL? = nil

    /// Speed multiplier for replay (1.0 = real-time, 2.0 = double speed)
    public var replaySpeedMultiplier: Double = 1.0

    /// File name for replay mode (JSON or GPX file in directory)
    public var replayFileName: String? = nil
    
    /// File URL for replay mode (alternative to replayFileName for external files)
    public var replayFileURL: URL? = nil

    /// Whether to loop replay when it ends
    public var loopReplay: Bool = false
    
    /// Enable background location updates (requires "Always" authorization)
    /// When enabled, location updates will continue even when the app is in the background
    public var allowsBackgroundLocationUpdates: Bool = false
    
    /// Automatically pause location updates when the device is likely stationary
    /// Defaults to true to save battery
    public var pausesLocationUpdatesAutomatically: Bool = true
    
    /// Automatically start/stop recording or replay sessions when location updates start/stop.
    /// When true, recording/replay sessions are automatically managed with location updates.
    /// When false, you must manually call start() and stop() methods to control sessions.
    /// Defaults to true for backward compatibility.
    public var shouldStopAndStartAutomatically: Bool = true

    public init() {}
}
