import Foundation
import CoreLocation

/// Manages recording of location events to JSON file
final class RecordingSession {
    typealias LocationRecordedCallback = (CLLocation, Int) -> Void
    
    private let directory: URL
    private let queue = DispatchQueue(label: "com.geologist.recording", qos: .utility)

    private var events: [GeoEvent] = []
    private var startTime: Date?
    private var fileName: String?
    private var locationEventIndex = 0 // Index counter for location events only

    private(set) var isRecording = false
    
    var onLocationRecorded: LocationRecordedCallback?

    init(directory: URL) throws {
        self.directory = directory
    }

    func start() throws {
        guard !isRecording else { return }

        queue.sync {
            self.startTime = Date()
            self.fileName = FileManager.generateRecordingFileName()
            self.events = []
            self.locationEventIndex = 0
            self.isRecording = true
        }
    }

    func stop() throws {
        guard isRecording else { return }

        try queue.sync {
            self.isRecording = false
            try self.flush(finalize: true)
        }
    }

    func recordLocation(_ location: CLLocation) {
        guard isRecording, let startTime = startTime else { return }

        queue.async {
            let relativeTime = location.timestamp.timeIntervalSince(startTime)
            let event = GeoEvent.location(
                timestamp: location.timestamp,
                relativeTime: relativeTime,
                location: location
            )
            self.events.append(event)
            
            // Get current index before incrementing
            let currentIndex = self.locationEventIndex
            self.locationEventIndex += 1

            // Notify callback on main queue
            if let callback = self.onLocationRecorded {
                DispatchQueue.main.async {
                    callback(location, currentIndex)
                }
            }

            // Flush every 10 events
            if self.events.count % 10 == 0 {
                try? self.flush(finalize: false)
            }
        }
    }

    func recordError(_ error: Error) {
        guard isRecording, let startTime = startTime else { return }

        queue.async {
            let now = Date()
            let relativeTime = now.timeIntervalSince(startTime)
            let event = GeoEvent.error(
                timestamp: now,
                relativeTime: relativeTime,
                error: error
            )
            self.events.append(event)
        }
    }

    private func flush(finalize: Bool) throws {
        guard let fileName = fileName, let startTime = startTime else { return }

        let fileURL = directory.appendingPathComponent(fileName)

        let duration = Date().timeIntervalSince(startTime)
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: startTime,
            device: self.deviceModel(),
            systemVersion: self.systemVersion(),
            duration: duration,
            eventCount: events.count
        )

        let recordingFile = RecordingFile(metadata: metadata, events: events)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(recordingFile)
        try data.write(to: fileURL, options: .atomic)
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
