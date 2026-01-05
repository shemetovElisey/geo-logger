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
