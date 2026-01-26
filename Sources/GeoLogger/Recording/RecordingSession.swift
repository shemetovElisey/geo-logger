import Foundation
import CoreLocation
import CoreData

/// Manages recording of location events using CoreData as temporary buffer.
/// Data is exported to JSON file on stop() and CoreData is cleared.
final class RecordingSession {
    typealias LocationRecordedCallback = (CLLocation, Int) -> Void
    typealias ExportCompletionCallback = (Result<URL, Error>) -> Void
    
    private let persistenceController: PersistenceController
    private let directory: URL
    private let queue = DispatchQueue(label: "com.geologist.recording", qos: .utility)
    private let exportQueue = DispatchQueue(label: "com.geologist.export", qos: .background)
    private var backgroundContext: NSManagedObjectContext?

    private var startTime: Date?
    private var currentRecordingId: UUID?
    private var fileName: String?
    private var locationEventIndex = 0 // Index counter for location events only

    private(set) var isRecording = false
    private(set) var isExporting = false
    
    var onLocationRecorded: LocationRecordedCallback?
    var onExportCompleted: ExportCompletionCallback?

    init(directory: URL? = nil, persistenceController: PersistenceController = .shared) throws {
        self.persistenceController = persistenceController
        self.directory = try directory ?? FileManager.default.geoLoggerDirectory(customDirectory: nil)
        
        // Try to recover and clean up any orphaned recordings from previous sessions (e.g., after crash)
        recoverAndCleanupOrphanedRecordings()
    }
    
    /// Try to export orphaned recordings to JSON, then delete them from CoreData
    private func recoverAndCleanupOrphanedRecordings() {
        let context = persistenceController.newBackgroundContext()
        context.performAndWait {
            let recordings = CDRecording.fetchAll(in: context)
            
            for recording in recordings {
                // Try to export before deleting
                if recording.eventCount > 0 {
                    do {
                        // Use existing name or generate new one
                        let fileName = recording.name ?? FileManager.generateRecordingFileName()
                        let recordingFile = recording.toRecordingFile()
                        let fileURL = directory.appendingPathComponent(fileName)
                        
                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .iso8601
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        
                        let data = try encoder.encode(recordingFile)
                        try data.write(to: fileURL, options: .atomic)
                        
                        print("GeoLogger: Recovered orphaned recording '\(fileName)' with \(recording.eventCount) events")
                    } catch {
                        print("GeoLogger: Failed to recover orphaned recording: \(error)")
                    }
                }
                
                // Always delete from CoreData
                context.delete(recording)
            }
            
            if !recordings.isEmpty {
                persistenceController.save(context: context)
            }
        }
    }

    func start() throws {
        guard !isRecording else { return }

        queue.sync(flags: .barrier) {
            self.startTime = Date()
            self.fileName = FileManager.generateRecordingFileName()
            self.locationEventIndex = 0
            self.isRecording = true
            
            // Create background context for this recording session
            self.backgroundContext = self.persistenceController.newBackgroundContext()
            
            // Create recording entity in CoreData (temporary storage)
            self.backgroundContext?.performAndWait {
                guard let context = self.backgroundContext else { return }
                
                let recording = CDRecording.create(
                    in: context,
                    name: self.fileName ?? "recording.json",
                    device: self.deviceModel(),
                    systemVersion: self.systemVersion()
                )
                self.currentRecordingId = recording.id
                
                self.persistenceController.save(context: context)
            }
        }
    }

    func stop() throws {
        guard isRecording else { return }

        queue.sync(flags: .barrier) {
            self.isRecording = false
            self.isExporting = true
        }
        
        // Capture values needed for async export
        let recordingId = currentRecordingId
        let context = backgroundContext
        let fileName = self.fileName
        let startTime = self.startTime
        
        // Clear references immediately (stop returns fast)
        queue.sync(flags: .barrier) {
            self.currentRecordingId = nil
            self.backgroundContext = nil
        }
        
        // Export asynchronously in background
        exportQueue.async { [weak self] in
            guard let self = self else { return }
            
            var exportResult: Result<URL, Error>?
            
            context?.performAndWait {
                guard let context = context,
                      let recordingId = recordingId,
                      let recording = CDRecording.fetch(byId: recordingId, in: context) else {
                    exportResult = .failure(RecordingSessionError.recordingNotFound)
                    return
                }
                
                // Update final duration
                if let startTime = startTime {
                    recording.duration = Date().timeIntervalSince(startTime)
                }
                
                // Try to export to JSON file
                do {
                    let fileURL = try self.exportToJSON(recording: recording, fileName: fileName)
                    exportResult = .success(fileURL)
                } catch {
                    exportResult = .failure(error)
                    print("GeoLogger: Failed to export recording: \(error)")
                }
                
                // Always delete from CoreData to avoid orphaned data
                context.delete(recording)
                self.persistenceController.save(context: context)
            }
            
            self.queue.sync(flags: .barrier) {
                self.isExporting = false
            }
            
            // Notify completion on main queue
            if let result = exportResult, let callback = self.onExportCompleted {
                DispatchQueue.main.async {
                    callback(result)
                }
            }
        }
    }
    
    /// Export recording to JSON file
    @discardableResult
    private func exportToJSON(recording: CDRecording, fileName: String?) throws -> URL {
        guard let fileName = fileName else {
            throw RecordingSessionError.missingFileName
        }
        
        let recordingFile = recording.toRecordingFile()
        let fileURL = directory.appendingPathComponent(fileName)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(recordingFile)
        try data.write(to: fileURL, options: .atomic)
        
        return fileURL
    }

    func recordLocation(_ location: CLLocation) {
        guard isRecording, let startTime = startTime else { return }

        queue.async {
            let relativeTime = location.timestamp.timeIntervalSince(startTime)
            
            // Get current index before incrementing
            let currentIndex = self.locationEventIndex
            self.locationEventIndex += 1
            
            // Save to CoreData
            self.backgroundContext?.performAndWait {
                guard let context = self.backgroundContext,
                      let recordingId = self.currentRecordingId,
                      let recording = CDRecording.fetch(byId: recordingId, in: context) else {
                    return
                }
                
                recording.addLocationEvent(
                    location: location,
                    relativeTime: relativeTime,
                    in: context
                )
                
                // Save every event for data safety
                self.persistenceController.save(context: context)
            }

            // Notify callback on main queue
            if let callback = self.onLocationRecorded {
                DispatchQueue.main.async {
                    callback(location, currentIndex)
                }
            }
        }
    }

    func recordError(_ error: Error) {
        guard isRecording, let startTime = startTime else { return }

        queue.async {
            let now = Date()
            let relativeTime = now.timeIntervalSince(startTime)
            
            // Save to CoreData
            self.backgroundContext?.performAndWait {
                guard let context = self.backgroundContext,
                      let recordingId = self.currentRecordingId,
                      let recording = CDRecording.fetch(byId: recordingId, in: context) else {
                    return
                }
                
                recording.addErrorEvent(
                    error: error,
                    relativeTime: relativeTime,
                    in: context
                )
                
                self.persistenceController.save(context: context)
            }
        }
    }

    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        return machine
    }

    private func systemVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "iOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

// MARK: - Errors

enum RecordingSessionError: LocalizedError {
    case recordingNotFound
    case missingFileName
    
    var errorDescription: String? {
        switch self {
        case .recordingNotFound:
            return "Recording not found in CoreData"
        case .missingFileName:
            return "Missing file name for export"
        }
    }
}
