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
    private var pendingWorkItem: DispatchWorkItem?

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
            self.cancelPendingEvents()
            self.isReplaying = false
        }
    }
    
    /// Seek to a specific time in the recording
    /// - Parameter time: Target time in seconds from the start of the recording
    func seek(to time: TimeInterval) {
        queue.async {
            self.cancelPendingEvents()
            
            // Find the event index that corresponds to the target time
            let targetIndex = self.findEventIndex(for: time)
            self.currentEventIndex = targetIndex
            
            // If replaying, update the replay start time to account for the seek
            if self.isReplaying {
                // Get the relative time of the event we're seeking to
                let targetRelativeTime: TimeInterval
                if targetIndex < self.recordingFile.events.count {
                    targetRelativeTime = self.recordingFile.events[targetIndex].relativeTime
                } else {
                    // Seeking past the end
                    targetRelativeTime = time
                }
                
                // Reset replay start time so that the next scheduled event happens at the right time
                let adjustedRelativeTime = targetRelativeTime / self.speedMultiplier
                self.replayStartTime = Date().addingTimeInterval(-adjustedRelativeTime)
                
                // Immediately deliver the location at the seek position
                if targetIndex < self.recordingFile.events.count {
                    let event = self.recordingFile.events[targetIndex]
                    self.deliverEvent(event, at: targetIndex)
                }
                
                // Continue scheduling from the new position
                self.currentEventIndex += 1
                self.scheduleNextEvent()
            } else {
                // Not replaying, just update position and deliver current location
                if targetIndex < self.recordingFile.events.count {
                    let event = self.recordingFile.events[targetIndex]
                    self.deliverEvent(event, at: targetIndex)
                }
            }
        }
    }
    
    /// Seek to a specific progress (0.0 to 1.0)
    /// - Parameter progress: Progress value from 0.0 (start) to 1.0 (end)
    func seek(toProgress progress: Double) {
        let clampedProgress = max(0.0, min(1.0, progress))
        let totalDuration = recordingFile.metadata.duration
        let targetTime = totalDuration * clampedProgress
        seek(to: targetTime)
    }
    
    /// Find the event index that corresponds to the given time
    private func findEventIndex(for time: TimeInterval) -> Int {
        // Binary search for efficiency
        var left = 0
        var right = recordingFile.events.count
        
        while left < right {
            let mid = (left + right) / 2
            let midTime = recordingFile.events[mid].relativeTime
            
            if midTime < time {
                left = mid + 1
            } else {
                right = mid
            }
        }
        
        // Return the index of the first event at or after the target time
        // But if we're at the end, return the last index
        return min(left, recordingFile.events.count - 1)
    }
    
    /// Get all location events up to a specific time
    /// - Parameter time: Target time in seconds from the start
    /// - Returns: Array of CLLocation objects from events up to the target time
    func getLocationsUpTo(time: TimeInterval) -> [CLLocation] {
        var locations: [CLLocation] = []
        for event in recordingFile.events {
            let eventTime: TimeInterval
            switch event {
            case .location(_, let relativeTime, _):
                eventTime = relativeTime
            case .error(_, let relativeTime, _):
                eventTime = relativeTime
            }
            
            if eventTime <= time {
                if case .location(_, _, let location) = event {
                    locations.append(location)
                }
            } else {
                break
            }
        }
        return locations
    }
    
    /// Cancel any pending scheduled events
    private func cancelPendingEvents() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
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

        // Create a cancellable work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isReplaying else { return }
            let eventIndex = self.currentEventIndex
            self.deliverEvent(event, at: eventIndex)
            self.currentEventIndex += 1
            self.scheduleNextEvent()
        }
        
        pendingWorkItem = workItem
        queue.asyncAfter(deadline: .now() + adjustedDelay, execute: workItem)
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

    private func deliverEvent(_ event: GeoEvent, at index: Int) {
        DispatchQueue.main.async {
            // Calculate current time based on event's relative time
            let currentTime: TimeInterval
            switch event {
            case .location(_, let relativeTime, _):
                currentTime = relativeTime
            case .error(_, let relativeTime, _):
                currentTime = relativeTime
            }
            
            // Calculate progress based on time (more accurate than index-based)
            let progress: Double
            let totalDuration = self.recordingFile.metadata.duration
            if totalDuration > 0 {
                progress = min(1.0, max(0.0, currentTime / totalDuration))
            } else {
                let totalEvents = self.recordingFile.events.count
                progress = totalEvents > 0 ? Double(index) / Double(totalEvents) : 0.0
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
