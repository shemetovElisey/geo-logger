import Foundation
import CoreData
import CoreLocation

/// CoreData entity for storing recording sessions
@objc(CDRecording)
class CDRecording: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var version: String?
    @NSManaged var recordedAt: Date?
    @NSManaged var device: String?
    @NSManaged var systemVersion: String?
    @NSManaged var duration: Double
    @NSManaged var eventCount: Int32
    @NSManaged var isActive: Bool
    @NSManaged var events: NSOrderedSet?
}

// MARK: - Convenience Methods

extension CDRecording {
    
    /// Create a new recording in the given context
    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        device: String,
        systemVersion: String
    ) -> CDRecording {
        let recording = CDRecording(context: context)
        recording.id = UUID()
        recording.name = name
        recording.version = "1.0"
        recording.recordedAt = Date()
        recording.device = device
        recording.systemVersion = systemVersion
        recording.duration = 0
        recording.eventCount = 0
        recording.isActive = true
        return recording
    }
    
    /// Fetch all recordings sorted by date (newest first)
    static func fetchAll(in context: NSManagedObjectContext) -> [CDRecording] {
        let request = NSFetchRequest<CDRecording>(entityName: "CDRecording")
        request.sortDescriptors = [NSSortDescriptor(key: "recordedAt", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch recordings: \(error)")
            return []
        }
    }
    
    /// Delete all recordings (cleanup orphaned data)
    static func deleteAll(in context: NSManagedObjectContext) {
        let request = NSFetchRequest<CDRecording>(entityName: "CDRecording")
        
        do {
            let recordings = try context.fetch(request)
            for recording in recordings {
                context.delete(recording)
            }
        } catch {
            print("Failed to delete all recordings: \(error)")
        }
    }
    
    /// Fetch recording by ID
    static func fetch(byId id: UUID, in context: NSManagedObjectContext) -> CDRecording? {
        let request = NSFetchRequest<CDRecording>(entityName: "CDRecording")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch recording: \(error)")
            return nil
        }
    }
    
    /// Fetch recording by name
    static func fetch(byName name: String, in context: NSManagedObjectContext) -> CDRecording? {
        let request = NSFetchRequest<CDRecording>(entityName: "CDRecording")
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch recording: \(error)")
            return nil
        }
    }
    
    /// Fetch the currently active recording (if any)
    static func fetchActive(in context: NSManagedObjectContext) -> CDRecording? {
        let request = NSFetchRequest<CDRecording>(entityName: "CDRecording")
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch active recording: \(error)")
            return nil
        }
    }
    
    /// Add a location event to this recording
    @discardableResult
    func addLocationEvent(
        location: CLLocation,
        relativeTime: TimeInterval,
        in context: NSManagedObjectContext
    ) -> CDGeoEvent {
        let event = CDGeoEvent(context: context)
        event.id = UUID()
        event.type = "location"
        event.timestamp = Date()
        event.relativeTime = relativeTime
        event.index = eventCount
        
        // Location data
        event.latitude = location.coordinate.latitude
        event.longitude = location.coordinate.longitude
        event.altitude = location.altitude
        event.horizontalAccuracy = location.horizontalAccuracy
        event.verticalAccuracy = location.verticalAccuracy
        event.course = location.course
        event.speed = location.speed
        event.locationTimestamp = location.timestamp
        
        event.recording = self
        
        // Update recording metadata
        eventCount += 1
        duration = relativeTime
        
        return event
    }
    
    /// Add an error event to this recording
    @discardableResult
    func addErrorEvent(
        error: Error,
        relativeTime: TimeInterval,
        in context: NSManagedObjectContext
    ) -> CDGeoEvent {
        let event = CDGeoEvent(context: context)
        event.id = UUID()
        event.type = "error"
        event.timestamp = Date()
        event.relativeTime = relativeTime
        event.index = eventCount
        
        // Error data
        let nsError = error as NSError
        event.errorCode = Int32(nsError.code)
        event.errorDomain = nsError.domain
        event.errorDescription = nsError.localizedDescription
        
        event.recording = self
        
        // Update recording metadata
        eventCount += 1
        
        return event
    }
    
    /// Mark recording as complete (inactive)
    func markAsComplete() {
        isActive = false
    }
    
    /// Convert to RecordingInfo
    func toRecordingInfo() -> RecordingInfo {
        RecordingInfo(
            id: id ?? UUID(),
            name: name ?? "Unknown",
            date: recordedAt ?? Date(),
            size: 0, // CoreData doesn't have file size concept
            duration: duration,
            eventCount: Int(eventCount)
        )
    }
    
    /// Convert to RecordingMetadata
    func toRecordingMetadata() -> RecordingMetadata {
        RecordingMetadata(
            version: version ?? "1.0",
            recordedAt: recordedAt ?? Date(),
            device: device ?? "Unknown",
            systemVersion: systemVersion ?? "Unknown",
            duration: duration,
            eventCount: Int(eventCount)
        )
    }
    
    /// Convert to RecordingFile (includes all events)
    func toRecordingFile() -> RecordingFile {
        let metadata = toRecordingMetadata()
        
        let geoEvents: [GeoEvent] = (events?.array as? [CDGeoEvent])?.compactMap { cdEvent in
            cdEvent.toGeoEvent()
        } ?? []
        
        return RecordingFile(metadata: metadata, events: geoEvents)
    }
    
    /// Get all events as an array
    var eventsArray: [CDGeoEvent] {
        (events?.array as? [CDGeoEvent]) ?? []
    }
}
