import Foundation

/// Complete recording file structure
struct RecordingFile: Codable {
    /// Metadata about the recording
    let metadata: RecordingMetadata

    /// Array of events (locations and errors)
    let events: [GeoEvent]
}
