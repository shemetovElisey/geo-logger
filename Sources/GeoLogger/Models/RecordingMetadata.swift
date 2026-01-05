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
