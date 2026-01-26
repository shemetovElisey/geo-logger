import Foundation
import CoreData
import CoreLocation

/// CoreData entity for storing geo events (locations or errors)
@objc(CDGeoEvent)
class CDGeoEvent: NSManagedObject {
    // Common attributes
    @NSManaged var id: UUID?
    @NSManaged var type: String?
    @NSManaged var timestamp: Date?
    @NSManaged var relativeTime: Double
    @NSManaged var index: Int32
    
    // Location attributes (optional, only for location events)
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var altitude: Double
    @NSManaged var horizontalAccuracy: Double
    @NSManaged var verticalAccuracy: Double
    @NSManaged var course: Double
    @NSManaged var speed: Double
    @NSManaged var locationTimestamp: Date?
    
    // Error attributes (optional, only for error events)
    @NSManaged var errorCode: Int32
    @NSManaged var errorDomain: String?
    @NSManaged var errorDescription: String?
    
    // Relationship
    @NSManaged var recording: CDRecording?
}

// MARK: - Convenience Methods

extension CDGeoEvent {
    
    /// Check if this is a location event
    var isLocationEvent: Bool {
        type == "location"
    }
    
    /// Check if this is an error event
    var isErrorEvent: Bool {
        type == "error"
    }
    
    /// Convert to CLLocation (for location events)
    func toCLLocation() -> CLLocation? {
        guard isLocationEvent else { return nil }
        
        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
        
        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: locationTimestamp ?? Date()
        )
    }
    
    /// Convert to NSError (for error events)
    func toError() -> NSError? {
        guard isErrorEvent else { return nil }
        
        return NSError(
            domain: errorDomain ?? "Unknown",
            code: Int(errorCode),
            userInfo: [
                NSLocalizedDescriptionKey: errorDescription ?? "Unknown error"
            ]
        )
    }
    
    /// Convert to GeoEvent
    func toGeoEvent() -> GeoEvent? {
        guard let eventTimestamp = timestamp else { return nil }
        
        switch type {
        case "location":
            guard let location = toCLLocation() else { return nil }
            return .location(
                timestamp: eventTimestamp,
                relativeTime: relativeTime,
                location: location
            )
            
        case "error":
            guard let error = toError() else { return nil }
            return .error(
                timestamp: eventTimestamp,
                relativeTime: relativeTime,
                error: error
            )
            
        default:
            return nil
        }
    }
    
    /// Fetch events for a recording, sorted by index
    static func fetchEvents(
        for recording: CDRecording,
        in context: NSManagedObjectContext
    ) -> [CDGeoEvent] {
        let request = NSFetchRequest<CDGeoEvent>(entityName: "CDGeoEvent")
        request.predicate = NSPredicate(format: "recording == %@", recording)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch events: \(error)")
            return []
        }
    }
    
    /// Fetch only location events for a recording
    static func fetchLocationEvents(
        for recording: CDRecording,
        in context: NSManagedObjectContext
    ) -> [CDGeoEvent] {
        let request = NSFetchRequest<CDGeoEvent>(entityName: "CDGeoEvent")
        request.predicate = NSPredicate(
            format: "recording == %@ AND type == %@",
            recording,
            "location"
        )
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch location events: \(error)")
            return []
        }
    }
    
    /// Fetch events up to a specific relative time
    static func fetchEvents(
        for recording: CDRecording,
        upTo relativeTime: TimeInterval,
        in context: NSManagedObjectContext
    ) -> [CDGeoEvent] {
        let request = NSFetchRequest<CDGeoEvent>(entityName: "CDGeoEvent")
        request.predicate = NSPredicate(
            format: "recording == %@ AND relativeTime <= %f",
            recording,
            relativeTime
        )
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch events: \(error)")
            return []
        }
    }
}
