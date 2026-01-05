import Foundation
import CoreLocation

/// Main class that wraps CLLocationManager with recording/replay capabilities
public final class GeoLogger: NSObject {
    private let configuration: GeoLoggerConfiguration
    private var locationManager: CLLocationManager?
    private var recordingSession: RecordingSession?
    private var replaySession: ReplaySession?

    /// Delegate for location updates and errors
    public weak var delegate: GeoLoggerDelegate?

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
        locationManager?.delegate = self

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

            replaySession?.onLocationUpdate = { [weak self] locations in
                guard let self = self else { return }
                self.delegate?.geoLogger(self, didUpdateLocations: locations)
            }

            replaySession?.onError = { [weak self] error in
                guard let self = self else { return }
                self.delegate?.geoLogger(self, didFailWithError: error)
            }
            
            replaySession?.onProgressUpdate = { [weak self] progress, currentTime in
                guard let self = self else { return }
                self.delegate?.geoLogger(self, didUpdateReplayProgress: progress, currentTime: currentTime)
            }
        } catch {
            delegate?.geoLogger(self, didFailWithError: error)
        }
    }

    private func setupPassthroughMode() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
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

extension GeoLogger: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Record if in record mode
        if configuration.mode == .record {
            locations.forEach { recordingSession?.recordLocation($0) }
        }

        // Forward to delegate
        delegate?.geoLogger(self, didUpdateLocations: locations)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Record if in record mode
        if configuration.mode == .record {
            recordingSession?.recordError(error)
        }

        // Forward to delegate
        delegate?.geoLogger(self, didFailWithError: error)
    }
}

