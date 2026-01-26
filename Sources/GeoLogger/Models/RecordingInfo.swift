import Foundation

/// Information about a recorded session file
public struct RecordingInfo: Identifiable {
    public var id: UUID
    
    /// File name of the recording
    public let name: String

    /// Date when recording was created
    public let date: Date

    /// File size in bytes (0 for CoreData recordings)
    public let size: Int64

    /// Duration of recording in seconds
    public let duration: TimeInterval

    /// Number of events in recording
    public let eventCount: Int

    public init(name: String, date: Date, size: Int64, duration: TimeInterval, eventCount: Int) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.size = size
        self.duration = duration
        self.eventCount = eventCount
    }
    
    public init(id: UUID, name: String, date: Date, size: Int64, duration: TimeInterval, eventCount: Int) {
        self.id = id
        self.name = name
        self.date = date
        self.size = size
        self.duration = duration
        self.eventCount = eventCount
    }
}
