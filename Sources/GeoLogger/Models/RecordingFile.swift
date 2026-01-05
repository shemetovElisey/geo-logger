import Foundation

/// Complete recording file structure
public struct RecordingFile: Codable {
    /// Metadata about the recording
    public let metadata: RecordingMetadata

    /// Array of events (locations and errors)
    public let events: [GeoEvent]
    
    public init(metadata: RecordingMetadata, events: [GeoEvent]) {
        self.metadata = metadata
        self.events = events
    }
}
