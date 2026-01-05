import Foundation

/// Metadata about a recording session
public struct RecordingMetadata: Codable {
    /// Format version for compatibility
    public let version: String

    /// When the recording started
    public let recordedAt: Date

    /// Device model (e.g., "iPhone 15 Pro")
    public let device: String

    /// OS version (e.g., "iOS 17.2")
    public let systemVersion: String

    /// Total duration of recording in seconds
    public let duration: TimeInterval

    /// Total number of events recorded
    public let eventCount: Int
    
    public init(version: String, recordedAt: Date, device: String, systemVersion: String, duration: TimeInterval, eventCount: Int) {
        self.version = version
        self.recordedAt = recordedAt
        self.device = device
        self.systemVersion = systemVersion
        self.duration = duration
        self.eventCount = eventCount
    }
}
