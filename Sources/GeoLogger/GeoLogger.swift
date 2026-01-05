import Foundation
import CoreLocation

/// Main class that wraps CLLocationManager with recording/replay capabilities.
/// 
/// In replay mode, GeoLogger creates a CLLocationManager and injects recorded location data
/// into its delegate methods, making it transparent to the application that data is being replayed.
public final class GeoLogger: NSObject {
    private let configuration: GeoLoggerConfiguration
    private var locationManager: CLLocationManager?
    private var recordingSession: RecordingSession?
    private var replaySession: ReplaySession?

    /// Delegate for CLLocationManager events (location updates and errors)
    public weak var locationManagerDelegate: CLLocationManagerDelegate?
    
    /// Delegate for GeoLogger-specific events (e.g., replay progress)
    public weak var geoLoggerDelegate: GeoLoggerDelegate?

    /// Initialize with configuration
    public init(configuration: GeoLoggerConfiguration) {
        self.configuration = configuration
        super.init()

        setupForMode()
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
        locationManager = CLLocationManager()
        locationManager?.delegate = self  // We intercept to record, then forward to user's delegate

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

        // Create CLLocationManager for replay mode to simulate standard behavior
        locationManager = CLLocationManager()
        locationManager?.delegate = self  // We inject replay data, then forward to user's delegate

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

            // Inject locations into CLLocationManager delegate methods to simulate real location updates
            // This makes replay mode transparent - the app receives data as if from real CLLocationManager
            replaySession?.onLocationUpdate = { [weak self] locations in
                guard let self = self, let manager = self.locationManager else { return }
                // Simulate CLLocationManager receiving these locations by calling delegate method directly
                // This triggers locationManager(_:didUpdateLocations:) which forwards to GeoLoggerDelegate
                self.locationManager(manager, didUpdateLocations: locations)
            }

            replaySession?.onError = { [weak self] error in
                guard let self = self, let manager = self.locationManager else { return }
                // Simulate CLLocationManager receiving this error by calling delegate method directly
                self.locationManager(manager, didFailWithError: error)
            }
            
            replaySession?.onProgressUpdate = { [weak self] progress, currentTime in
                guard let self = self else { return }
                self.geoLoggerDelegate?.geoLogger(self, didUpdateReplayProgress: progress, currentTime: currentTime)
            }
        } catch {
            // Forward error through CLLocationManagerDelegate
            if let manager = locationManager {
                locationManager(manager, didFailWithError: error)
            }
        }
    }

    private func setupPassthroughMode() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self  // We just forward to user's delegate
    }

    // MARK: - Public API (mirrors CLLocationManager)

    public func requestWhenInUseAuthorization() {
        locationManager?.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        locationManager?.requestAlwaysAuthorization()
    }

    public func startUpdatingLocation() {
        switch configuration.mode {
        case .record:
            try? recordingSession?.start()
            locationManager?.startUpdatingLocation()
        case .replay:
            replaySession?.start()
        case .passthrough:
            locationManager?.startUpdatingLocation()
        }
    }

    public func stopUpdatingLocation() {
        switch configuration.mode {
        case .record:
            try? recordingSession?.stop()
            locationManager?.stopUpdatingLocation()
        case .replay:
            replaySession?.stop()
        case .passthrough:
            locationManager?.stopUpdatingLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

// MARK: - CLLocationManagerDelegate

extension GeoLogger: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Record if in record mode
        if configuration.mode == .record {
            locations.forEach { recordingSession?.recordLocation($0) }
        }

        // Forward to user's CLLocationManagerDelegate
        locationManagerDelegate?.locationManager?(manager, didUpdateLocations: locations)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Record if in record mode
        if configuration.mode == .record {
            recordingSession?.recordError(error)
        }

        // Forward to user's CLLocationManagerDelegate
        locationManagerDelegate?.locationManager?(manager, didFailWithError: error)
    }
}

