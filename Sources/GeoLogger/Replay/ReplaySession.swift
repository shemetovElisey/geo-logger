import Foundation
import CoreLocation

/// Manages replay of recorded location events
final class ReplaySession {
    typealias LocationCallback = ([CLLocation]) -> Void
    typealias ErrorCallback = (Error) -> Void
    typealias ProgressCallback = (Double, TimeInterval) -> Void // progress (0.0-1.0), currentTime

    private let recordingFile: RecordingFile
    private let speedMultiplier: Double
    private let loop: Bool
    private let queue = DispatchQueue(label: "com.geologist.replay", qos: .userInitiated)

    private var currentEventIndex = 0
    private var replayStartTime: Date?
    private(set) var isReplaying = false

    var onLocationUpdate: LocationCallback?
    var onError: ErrorCallback?
    var onProgressUpdate: ProgressCallback?

    /// Initialize with file URL (auto-detects JSON or GPX)
    init(fileURL: URL, speedMultiplier: Double, loop: Bool) throws {
        let isGPX = fileURL.pathExtension.lowercased() == "gpx"
        
        if isGPX {
            self.recordingFile = try GPXParser.parseGPX(from: fileURL)
        } else {
            // Load and decode JSON recording file
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.recordingFile = try decoder.decode(RecordingFile.self, from: data)
        }

        self.speedMultiplier = speedMultiplier
        self.loop = loop
    }
    
    /// Initialize with RecordingFile directly
    init(recordingFile: RecordingFile, speedMultiplier: Double, loop: Bool) {
        self.recordingFile = recordingFile
        self.speedMultiplier = speedMultiplier
        self.loop = loop
    }

    func start() {
        guard !isReplaying else { return }

        queue.async {
            self.isReplaying = true
            self.replayStartTime = Date()
            self.currentEventIndex = 0
            self.scheduleNextEvent()
        }
    }

    func stop() {
        queue.async {
            self.isReplaying = false
        }
    }

    private func scheduleNextEvent() {
        guard isReplaying else { return }
        guard currentEventIndex < recordingFile.events.count else {
            if loop {
                currentEventIndex = 0
                replayStartTime = Date()
                scheduleNextEvent()
            } else {
                isReplaying = false
            }
            return
        }

        let event = recordingFile.events[currentEventIndex]
        let adjustedDelay = self.calculateDelay(for: event)

        queue.asyncAfter(deadline: .now() + adjustedDelay) {
            self.deliverEvent(event)
            self.currentEventIndex += 1
            self.scheduleNextEvent()
        }
    }

    private func calculateDelay(for event: GeoEvent) -> TimeInterval {
        guard let replayStartTime = replayStartTime else { return 0 }

        let relativeTime: TimeInterval
        switch event {
        case .location(_, let rt, _):
            relativeTime = rt
        case .error(_, let rt, _):
            relativeTime = rt
        }

        let adjustedRelativeTime = relativeTime / speedMultiplier
        let targetTime = replayStartTime.addingTimeInterval(adjustedRelativeTime)
        let delay = targetTime.timeIntervalSinceNow

        return max(0, delay)
    }

    private func deliverEvent(_ event: GeoEvent) {
        DispatchQueue.main.async {
            // Calculate and report progress
            let totalEvents = self.recordingFile.events.count
            let progress = totalEvents > 0 ? Double(self.currentEventIndex) / Double(totalEvents) : 0.0
            
            // Calculate current time based on event's relative time
            let currentTime: TimeInterval
            switch event {
            case .location(_, let relativeTime, _):
                currentTime = relativeTime
            case .error(_, let relativeTime, _):
                currentTime = relativeTime
            }
            
            self.onProgressUpdate?(progress, currentTime)
            
            // Deliver the event
            switch event {
            case .location(_, _, let location):
                self.onLocationUpdate?([location])
            case .error(_, _, let error):
                self.onError?(error)
            }
        }
    }
}
