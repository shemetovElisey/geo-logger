import Foundation
import CoreData

/// Manages CoreData stack for GeoLogger
final class PersistenceController {
    
    /// Shared instance for production use
    static let shared = PersistenceController()
    
    /// Preview instance for SwiftUI previews and testing
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    /// The persistent container
    let container: NSPersistentContainer
    
    /// Main context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Create a background context for write operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Initialize the persistence controller
    /// - Parameter inMemory: If true, uses in-memory store (for testing/previews)
    init(inMemory: Bool = false) {
        // Create the managed object model programmatically
        let model = Self.createManagedObjectModel()
        
        container = NSPersistentContainer(name: "GeoLogger", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use app's document directory for persistent storage
            let storeURL = Self.defaultStoreURL()
            container.persistentStoreDescriptions.first?.url = storeURL
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("CoreData failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Default store URL in app's document directory
    private static func defaultStoreURL() -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsURL = urls[0]
        return documentsURL.appendingPathComponent("GeoLogger.sqlite")
    }
    
    /// Create the managed object model programmatically
    /// This approach is necessary for Swift Package Manager compatibility
    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // MARK: - CDRecording Entity
        let recordingEntity = NSEntityDescription()
        recordingEntity.name = "CDRecording"
        recordingEntity.managedObjectClassName = NSStringFromClass(CDRecording.self)
        
        let recordingIdAttr = NSAttributeDescription()
        recordingIdAttr.name = "id"
        recordingIdAttr.attributeType = .UUIDAttributeType
        
        let recordingNameAttr = NSAttributeDescription()
        recordingNameAttr.name = "name"
        recordingNameAttr.attributeType = .stringAttributeType
        
        let recordingVersionAttr = NSAttributeDescription()
        recordingVersionAttr.name = "version"
        recordingVersionAttr.attributeType = .stringAttributeType
        recordingVersionAttr.defaultValue = "1.0"
        
        let recordingRecordedAtAttr = NSAttributeDescription()
        recordingRecordedAtAttr.name = "recordedAt"
        recordingRecordedAtAttr.attributeType = .dateAttributeType
        
        let recordingDeviceAttr = NSAttributeDescription()
        recordingDeviceAttr.name = "device"
        recordingDeviceAttr.attributeType = .stringAttributeType
        
        let recordingSystemVersionAttr = NSAttributeDescription()
        recordingSystemVersionAttr.name = "systemVersion"
        recordingSystemVersionAttr.attributeType = .stringAttributeType
        
        let recordingDurationAttr = NSAttributeDescription()
        recordingDurationAttr.name = "duration"
        recordingDurationAttr.attributeType = .doubleAttributeType
        recordingDurationAttr.defaultValue = 0.0
        
        let recordingEventCountAttr = NSAttributeDescription()
        recordingEventCountAttr.name = "eventCount"
        recordingEventCountAttr.attributeType = .integer32AttributeType
        recordingEventCountAttr.defaultValue = 0
        
        let recordingIsActiveAttr = NSAttributeDescription()
        recordingIsActiveAttr.name = "isActive"
        recordingIsActiveAttr.attributeType = .booleanAttributeType
        recordingIsActiveAttr.defaultValue = false
        
        // MARK: - CDGeoEvent Entity
        let eventEntity = NSEntityDescription()
        eventEntity.name = "CDGeoEvent"
        eventEntity.managedObjectClassName = NSStringFromClass(CDGeoEvent.self)
        
        let eventIdAttr = NSAttributeDescription()
        eventIdAttr.name = "id"
        eventIdAttr.attributeType = .UUIDAttributeType
        
        let eventTypeAttr = NSAttributeDescription()
        eventTypeAttr.name = "type"
        eventTypeAttr.attributeType = .stringAttributeType
        
        let eventTimestampAttr = NSAttributeDescription()
        eventTimestampAttr.name = "timestamp"
        eventTimestampAttr.attributeType = .dateAttributeType
        
        let eventRelativeTimeAttr = NSAttributeDescription()
        eventRelativeTimeAttr.name = "relativeTime"
        eventRelativeTimeAttr.attributeType = .doubleAttributeType
        
        let eventIndexAttr = NSAttributeDescription()
        eventIndexAttr.name = "index"
        eventIndexAttr.attributeType = .integer32AttributeType
        
        // Location data attributes
        let latitudeAttr = NSAttributeDescription()
        latitudeAttr.name = "latitude"
        latitudeAttr.attributeType = .doubleAttributeType
        latitudeAttr.isOptional = true
        
        let longitudeAttr = NSAttributeDescription()
        longitudeAttr.name = "longitude"
        longitudeAttr.attributeType = .doubleAttributeType
        longitudeAttr.isOptional = true
        
        let altitudeAttr = NSAttributeDescription()
        altitudeAttr.name = "altitude"
        altitudeAttr.attributeType = .doubleAttributeType
        altitudeAttr.isOptional = true
        
        let horizontalAccuracyAttr = NSAttributeDescription()
        horizontalAccuracyAttr.name = "horizontalAccuracy"
        horizontalAccuracyAttr.attributeType = .doubleAttributeType
        horizontalAccuracyAttr.isOptional = true
        
        let verticalAccuracyAttr = NSAttributeDescription()
        verticalAccuracyAttr.name = "verticalAccuracy"
        verticalAccuracyAttr.attributeType = .doubleAttributeType
        verticalAccuracyAttr.isOptional = true
        
        let courseAttr = NSAttributeDescription()
        courseAttr.name = "course"
        courseAttr.attributeType = .doubleAttributeType
        courseAttr.isOptional = true
        
        let speedAttr = NSAttributeDescription()
        speedAttr.name = "speed"
        speedAttr.attributeType = .doubleAttributeType
        speedAttr.isOptional = true
        
        let locationTimestampAttr = NSAttributeDescription()
        locationTimestampAttr.name = "locationTimestamp"
        locationTimestampAttr.attributeType = .dateAttributeType
        locationTimestampAttr.isOptional = true
        
        // Error data attributes
        let errorCodeAttr = NSAttributeDescription()
        errorCodeAttr.name = "errorCode"
        errorCodeAttr.attributeType = .integer32AttributeType
        errorCodeAttr.isOptional = true
        
        let errorDomainAttr = NSAttributeDescription()
        errorDomainAttr.name = "errorDomain"
        errorDomainAttr.attributeType = .stringAttributeType
        errorDomainAttr.isOptional = true
        
        let errorDescriptionAttr = NSAttributeDescription()
        errorDescriptionAttr.name = "errorDescription"
        errorDescriptionAttr.attributeType = .stringAttributeType
        errorDescriptionAttr.isOptional = true
        
        // Set entity attributes
        recordingEntity.properties = [
            recordingIdAttr, recordingNameAttr, recordingVersionAttr,
            recordingRecordedAtAttr, recordingDeviceAttr, recordingSystemVersionAttr,
            recordingDurationAttr, recordingEventCountAttr, recordingIsActiveAttr
        ]
        
        eventEntity.properties = [
            eventIdAttr, eventTypeAttr, eventTimestampAttr, eventRelativeTimeAttr, eventIndexAttr,
            latitudeAttr, longitudeAttr, altitudeAttr,
            horizontalAccuracyAttr, verticalAccuracyAttr,
            courseAttr, speedAttr, locationTimestampAttr,
            errorCodeAttr, errorDomainAttr, errorDescriptionAttr
        ]
        
        // MARK: - Relationships
        let eventsRelation = NSRelationshipDescription()
        eventsRelation.name = "events"
        eventsRelation.destinationEntity = eventEntity
        eventsRelation.minCount = 0
        eventsRelation.maxCount = 0 // To-many
        eventsRelation.deleteRule = .cascadeDeleteRule
        eventsRelation.isOrdered = true
        
        let recordingRelation = NSRelationshipDescription()
        recordingRelation.name = "recording"
        recordingRelation.destinationEntity = recordingEntity
        recordingRelation.minCount = 1
        recordingRelation.maxCount = 1 // To-one
        recordingRelation.deleteRule = .nullifyDeleteRule
        
        eventsRelation.inverseRelationship = recordingRelation
        recordingRelation.inverseRelationship = eventsRelation
        
        recordingEntity.properties.append(eventsRelation)
        eventEntity.properties.append(recordingRelation)
        
        model.entities = [recordingEntity, eventEntity]
        
        return model
    }
    
    // MARK: - Save Context
    
    /// Save the view context if there are changes
    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("CoreData save error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Save a background context
    func save(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("CoreData save error: \(error.localizedDescription)")
            }
        }
    }
}
