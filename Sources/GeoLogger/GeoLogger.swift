import Foundation
import CoreLocation

/// GeoLogger is a subclass of CLLocationManager with recording and replay capabilities.
/// 
/// Use GeoLogger as a drop-in replacement for CLLocationManager. In replay mode,
/// recorded location data is injected into delegate methods, making it transparent
/// to the application that data is being replayed.
///
/// Data is stored in CoreData for persistence and efficient querying.
open class GeoLogger: CLLocationManager {
    var recordingSession: RecordingSession?  // internal for InternalDelegate access
    var replaySession: ReplaySession?  // internal for InternalDelegate access
    private let configuration: GeoLoggerConfiguration
    private var internalDelegate: InternalDelegate?
    
    /// Last location received (used in replay mode to override location property)
    private var lastLocation: CLLocation?
    
    /// Delegate for GeoLogger-specific events (e.g., replay progress)
    public weak var geoLoggerDelegate: GeoLoggerDelegate?
    
    /// Override location property to return lastLocation in replay mode
    public override var location: CLLocation? {
        if configuration.mode == .replay {
            return lastLocation
        }
        return super.location
    }
    
    /// Initialize with configuration
    public init(configuration: GeoLoggerConfiguration) {
        self.configuration = configuration
        super.init()
        
        setupForMode()
        allowsBackgroundLocationUpdates = configuration.allowsBackgroundLocationUpdates
    }
    
    /// Start recording or replay session based on the current mode.
    /// This method manually starts the session without calling startUpdatingLocation().
    public func start() {
        switch configuration.mode {
        case .record:
            try? recordingSession?.start()
        case .replay:
            replaySession?.start()
        case .passthrough:
            break
        }
    }
    
    /// Stop recording or replay session based on the current mode.
    /// This method manually stops the session without calling stopUpdatingLocation().
    public func stop() {
        switch configuration.mode {
        case .record:
            try? recordingSession?.stop()
        case .replay:
            replaySession?.stop()
        case .passthrough:
            break
        }
    }
    
    /// Seek to a specific time in the replay (only works in replay mode)
    /// - Parameter time: Target time in seconds from the start of the recording
    public func seek(to time: TimeInterval) {
        guard configuration.mode == .replay else {
            print("GeoLogger: seek(to:) is only available in replay mode")
            return
        }
        replaySession?.seek(to: time)
    }
    
    /// Seek to a specific progress in the replay (only works in replay mode)
    /// - Parameter progress: Progress value from 0.0 (start) to 1.0 (end)
    public func seek(toProgress progress: Double) {
        guard configuration.mode == .replay else {
            print("GeoLogger: seek(toProgress:) is only available in replay mode")
            return
        }
        replaySession?.seek(toProgress: progress)
    }
    
    /// Get all locations up to a specific time (only works in replay mode)
    /// - Parameter time: Target time in seconds from the start
    /// - Returns: Array of CLLocation objects from events up to the target time
    public func getLocationsUpTo(time: TimeInterval) -> [CLLocation] {
        guard configuration.mode == .replay else {
            return []
        }
        return replaySession?.getLocationsUpTo(time: time) ?? []
    }
    
    /// Get location at a specific progress (only works in replay mode)
    /// - Parameter progress: Progress value from 0.0 (start) to 1.0 (end)
    /// - Returns: CLLocation at the specified progress, or nil if no location events exist
    public func getLocation(atProgress progress: Double) -> CLLocation? {
        guard configuration.mode == .replay else {
            print("GeoLogger: getLocation(atProgress:) is only available in replay mode")
            return nil
        }
        return replaySession?.getLocation(atProgress: progress)
    }
    
    /// Get the first location from the recording (only works in replay mode)
    /// - Returns: First CLLocation in the recording, or nil if no location events exist
    public func getFirstLocation() -> CLLocation? {
        return getLocation(atProgress: 0.0)
    }
    
    /// Get the last location from the recording (only works in replay mode)
    /// - Returns: Last CLLocation in the recording, or nil if no location events exist
    public func getLastLocation() -> CLLocation? {
        return getLocation(atProgress: 1.0)
    }
    
    private func setupForMode() {
        switch configuration.mode {
        case .record:
            setupRecordMode()
        case .replay:
            setupReplayMode()
        case .passthrough:
            setupPassthroughMode()
        }
    }
    
    private func setupRecordMode() {
        // Set up internal delegate to intercept location updates for recording
        internalDelegate = InternalDelegate(geoLogger: self, configuration: configuration)
        super.delegate = internalDelegate
        
        // Don't set allowsBackgroundLocationUpdates here - it must be set after authorization
        // It will be set in locationManager(_:didChangeAuthorization:) when authorization is granted
        pausesLocationUpdatesAutomatically = configuration.pausesLocationUpdatesAutomatically
        
        do {
            let directory = try FileManager.default.geoLoggerDirectory(
                customDirectory: configuration.directory
            )
            recordingSession = try RecordingSession(directory: directory)
            
            // Set up callback for recording progress
            recordingSession?.onLocationRecorded = { [weak self] location, index in
                guard let self = self else { return }
                self.geoLoggerDelegate?.geoLogger(self, didRecordLocation: location, atIndex: index)
            }
        } catch {
            print("GeoLogger: Failed to setup recording session: \(error)")
        }
    }
    
    private func setupReplayMode() {
        // Set up internal delegate to inject replay data
        internalDelegate = InternalDelegate(geoLogger: self, configuration: configuration)
        super.delegate = internalDelegate
        
        do {
            let fileURL: URL
            
            if let replayFileURL = configuration.replayFileURL {
                // Use provided file URL directly
                fileURL = replayFileURL
            } else if let fileName = configuration.replayFileName {
                // Build URL from directory and file name
                let directory = try FileManager.default.geoLoggerDirectory(
                    customDirectory: configuration.directory
                )
                fileURL = directory.appendingPathComponent(fileName)
            } else {
                print("GeoLogger: Replay mode requires replayFileName or replayFileURL")
                return
            }
            
            replaySession = try ReplaySession(
                fileURL: fileURL,
                speedMultiplier: configuration.replaySpeedMultiplier,
                loop: configuration.loopReplay
            )
            
            // Inject locations into delegate methods to simulate real location updates
            replaySession?.onLocationUpdate = { [weak self] locations in
                guard let self = self else { return }
                // Store last location for location property override
                if let lastLocation = locations.last {
                    self.lastLocation = lastLocation
                }
                // Call delegate method directly to simulate CLLocationManager receiving locations
                self.internalDelegate?.locationManager(self, didUpdateLocations: locations)
            }
            
            replaySession?.onError = { [weak self] error in
                guard let self = self else { return }
                // Call delegate method directly to simulate CLLocationManager receiving error
                self.internalDelegate?.locationManager(self, didFailWithError: error)
            }
            
            replaySession?.onProgressUpdate = { [weak self] progress, currentTime in
                guard let self = self else { return }
                self.geoLoggerDelegate?.geoLogger(self, didUpdateReplayProgress: progress, currentTime: currentTime)
            }
        } catch {
            // Forward error through delegate
            internalDelegate?.locationManager(self, didFailWithError: error)
        }
    }
    
    private func setupPassthroughMode() {
        // Set up internal delegate to forward to user's delegate
        internalDelegate = InternalDelegate(geoLogger: self, configuration: configuration)
        super.delegate = internalDelegate
        
        // Don't set allowsBackgroundLocationUpdates here - it must be set after authorization
        // It will be set in locationManager(_:didChangeAuthorization:) when authorization is granted
        pausesLocationUpdatesAutomatically = configuration.pausesLocationUpdatesAutomatically
    }
    
    // MARK: - Override delegate property
    
    /// The delegate object to receive update events.
    /// In record and replay modes, GeoLogger uses an internal delegate to intercept events.
    public override var delegate: CLLocationManagerDelegate? {
        get {
            return internalDelegate?.userDelegate
        }
        set {
            internalDelegate?.userDelegate = newValue
        }
    }
    
    // MARK: - Override location update methods
    
    public override func startUpdatingLocation() {
        switch configuration.mode {
        case .record:
            if configuration.shouldStopAndStartAutomatically {
                try? recordingSession?.start()
            }
            super.startUpdatingLocation()
        case .replay:
            if configuration.shouldStopAndStartAutomatically {
                replaySession?.start()
            }
        case .passthrough:
            super.startUpdatingLocation()
        }
    }
    
    public override func stopUpdatingLocation() {
        switch configuration.mode {
        case .record:
            if configuration.shouldStopAndStartAutomatically {
                try? recordingSession?.stop()
            } else {
                recordingSession?.recordError(
                    NSError(
                        domain: "GeoLogger",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "User stopped location updates while recording."]
                    )
                )
            }
            super.stopUpdatingLocation()
        case .replay:
            if configuration.shouldStopAndStartAutomatically {
                replaySession?.stop()
            }
        case .passthrough:
            super.stopUpdatingLocation()
        }
    }
}

// MARK: - Internal Delegate

/// Internal delegate that intercepts CLLocationManagerDelegate calls
private class InternalDelegate: NSObject, CLLocationManagerDelegate {
    weak var geoLogger: GeoLogger?
    let configuration: GeoLoggerConfiguration
    weak var userDelegate: CLLocationManagerDelegate?
    
    init(geoLogger: GeoLogger, configuration: GeoLoggerConfiguration) {
        self.geoLogger = geoLogger
        self.configuration = configuration
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let geoLogger = geoLogger else { return }
        
        // Record if in record mode
        if configuration.mode == .record {
            locations.forEach { geoLogger.recordingSession?.recordLocation($0) }
        }
        
        // Forward to user's delegate
        userDelegate?.locationManager?(manager, didUpdateLocations: locations)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let geoLogger = geoLogger else { return }
        
        // Record if in record mode
        if configuration.mode == .record {
            geoLogger.recordingSession?.recordError(error)
        }
        
        // Forward to user's delegate
        userDelegate?.locationManager?(manager, didFailWithError: error)
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // Forward to user's delegate
        userDelegate?.locationManagerDidPauseLocationUpdates?(manager)
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        // Forward to user's delegate
        userDelegate?.locationManagerDidResumeLocationUpdates?(manager)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard let geoLogger = geoLogger else { return }
        
        geoLogger.allowsBackgroundLocationUpdates = configuration.allowsBackgroundLocationUpdates
        
        // Forward to user's delegate
        userDelegate?.locationManager?(manager, didChangeAuthorization: status)
    }
}

