import Foundation
import CoreLocation

/// GeoLogger is a subclass of CLLocationManager with recording and replay capabilities.
/// 
/// Use GeoLogger as a drop-in replacement for CLLocationManager. In replay mode,
/// recorded location data is injected into delegate methods, making it transparent
/// to the application that data is being replayed.
public class GeoLogger: CLLocationManager {
    private let configuration: GeoLoggerConfiguration
    var recordingSession: RecordingSession?  // internal for InternalDelegate access
    var replaySession: ReplaySession?  // internal for InternalDelegate access
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
        } catch {
            print("GeoLogger: Failed to setup recording session: \(error)")
        }
    }
    
    private func setupReplayMode() {
        guard let fileName = configuration.replayFileName else {
            print("GeoLogger: Replay mode requires replayFileName")
            return
        }
        
        // Set up internal delegate to inject replay data
        internalDelegate = InternalDelegate(geoLogger: self, configuration: configuration)
        super.delegate = internalDelegate
        
        do {
            let directory = try FileManager.default.geoLoggerDirectory(
                customDirectory: configuration.directory
            )
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Check if file is GPX or JSON
            let isGPX = fileName.lowercased().hasSuffix(".gpx")
            let recordingFile: RecordingFile
            
            if isGPX {
                // Parse GPX file
                recordingFile = try GPXParser.parseGPX(from: fileURL)
            } else {
                // Parse JSON file
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                recordingFile = try decoder.decode(RecordingFile.self, from: data)
            }
            
            // Create ReplaySession from RecordingFile
            replaySession = try ReplaySession(
                recordingFile: recordingFile,
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
            try? recordingSession?.start()
            super.startUpdatingLocation()
        case .replay:
            replaySession?.start()
        case .passthrough:
            super.startUpdatingLocation()
        }
    }
    
    public override func stopUpdatingLocation() {
        switch configuration.mode {
        case .record:
            try? recordingSession?.stop()
            super.stopUpdatingLocation()
        case .replay:
            replaySession?.stop()
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

