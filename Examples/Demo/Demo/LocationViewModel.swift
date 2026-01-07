//
//  LocationViewModel.swift
//  Demo
//
//  Created by Elisey Shemetov on 05.01.2026.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation
import GeoLogger

@MainActor
class LocationViewModel: NSObject, ObservableObject {
    @Published var geoLogger: GeoLogger?
    @Published var isRecording = false
    @Published var isReplaying = false
    @Published var recordedEventsCount = 0
    @Published var recordings: [RecordingInfo] = []
    @Published var selectedRecording: RecordingInfo?
    @Published var replaySpeed: Double = 1.0
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showShareSheet = false
    @Published var shareURL: URL?
    @Published var locationHistory: [CLLocation] = []
    @Published var replayProgress: Double = 0.0
    @Published var replayCurrentTime: TimeInterval = 0.0
    @Published var allowsBackgroundLocationUpdates: Bool = false
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    private var recordingManager = RecordingManager.shared
    private var recordingStartTime: Date?
    private var temporaryReplayFileURL: URL?
    
    // Computed property that reads location directly from GeoLogger
    var currentLocation: CLLocation? {
        geoLogger?.location
    }
    
    
    override init() {
        super.init()
        refreshRecordings()
    }
    
    func startRecording() {
        var config = GeoLoggerConfiguration()
        config.mode = .record
        config.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
        config.pausesLocationUpdatesAutomatically = true
        
        let logger = GeoLogger(configuration: config)
        logger.delegate = self  // Use standard CLLocationManagerDelegate
        logger.geoLoggerDelegate = self
        
        // Request appropriate authorization based on background mode
        if allowsBackgroundLocationUpdates {
            logger.requestAlwaysAuthorization()
        } else {
            logger.requestWhenInUseAuthorization()
        }
        
        logger.startUpdatingLocation()
        
        geoLogger = logger
        isRecording = true
        recordedEventsCount = 0
        recordingStartTime = Date()
        locationHistory = []
    }
    
    func stopRecording() {
        geoLogger?.stopUpdatingLocation()
        geoLogger = nil
        isRecording = false
        
        // Give time for file to be written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshRecordings()
        }
    }
    
    func startReplay() {
        guard let selectedRecording = selectedRecording else { return }
        
        var config = GeoLoggerConfiguration()
        config.mode = .replay
        config.replayFileName = selectedRecording.name
        config.replaySpeedMultiplier = replaySpeed
        config.loopReplay = false
        
        let logger = GeoLogger(configuration: config)
        logger.delegate = self  // Use standard CLLocationManagerDelegate
        logger.geoLoggerDelegate = self
        logger.startUpdatingLocation()
        
        geoLogger = logger
        isReplaying = true
        locationHistory = []
        replayProgress = 0.0
        replayCurrentTime = 0.0
    }
    
    func startReplay(from fileURL: URL) {
        do {
            // Clean up any previous temporary file
            cleanupTemporaryReplayFile()
            
            // Determine file extension
            let fileExtension = fileURL.pathExtension.lowercased()
            let isGPX = fileExtension == "gpx"
            let tempExtension = isGPX ? "gpx" : "json"
            
            // Create temporary file in GeoLogger directory
            let directory = try FileManager.default.geoLoggerDirectory(customDirectory: nil)
            let tempFileName = "temp_replay_\(UUID().uuidString).\(tempExtension)"
            let tempFileURL = directory.appendingPathComponent(tempFileName)
            
            // Copy file to temporary location
            try FileManager.default.copyItem(at: fileURL, to: tempFileURL)
            temporaryReplayFileURL = tempFileURL
            
            // Use GeoLogger's replay mode with the temporary file
            var config = GeoLoggerConfiguration()
            config.mode = .replay
            config.replayFileName = tempFileName
            config.replaySpeedMultiplier = replaySpeed
            config.loopReplay = false
            
            let logger = GeoLogger(configuration: config)
            logger.delegate = self
            logger.geoLoggerDelegate = self
            logger.startUpdatingLocation()
            
            geoLogger = logger
            isReplaying = true
            locationHistory = []
            replayProgress = 0.0
            replayCurrentTime = 0.0
            
        } catch {
            errorMessage = "Failed to load file: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func startReplay(fromClipboard text: String) {
        do {
            // Clean up any previous temporary file
            cleanupTemporaryReplayFile()
            
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let directory = try FileManager.default.geoLoggerDirectory(customDirectory: nil)
            let tempFileName: String
            let fileData: Data
            
            // Detect format and prepare data
            if trimmedText.hasPrefix("{") || trimmedText.hasPrefix("[") {
                // JSON format
                guard let data = text.data(using: .utf8) else {
                    throw NSError(domain: "LocationViewModel", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to convert clipboard text to data"
                    ])
                }
                // Validate JSON by trying to decode it
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                _ = try decoder.decode(RecordingFile.self, from: data)
                tempFileName = "temp_replay_\(UUID().uuidString).json"
                fileData = data
            } else if trimmedText.hasPrefix("<?xml") || trimmedText.contains("<gpx") {
                // GPX format
                guard let data = text.data(using: .utf8) else {
                    throw NSError(domain: "LocationViewModel", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to convert clipboard text to data"
                    ])
                }
                // Validate GPX by trying to parse it
                _ = try GPXParser.parseGPX(from: data)
                tempFileName = "temp_replay_\(UUID().uuidString).gpx"
                fileData = data
            } else {
                throw NSError(domain: "LocationViewModel", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Unsupported format. Expected JSON or GPX."
                ])
            }
            
            // Write to temporary file
            let tempFileURL = directory.appendingPathComponent(tempFileName)
            try fileData.write(to: tempFileURL)
            temporaryReplayFileURL = tempFileURL
            
            // Use GeoLogger's replay mode with the temporary file
            var config = GeoLoggerConfiguration()
            config.mode = .replay
            config.replayFileName = tempFileName
            config.replaySpeedMultiplier = replaySpeed
            config.loopReplay = false
            
            let logger = GeoLogger(configuration: config)
            logger.delegate = self
            logger.geoLoggerDelegate = self
            logger.startUpdatingLocation()
            
            geoLogger = logger
            isReplaying = true
            locationHistory = []
            replayProgress = 0.0
            replayCurrentTime = 0.0
            
        } catch {
            errorMessage = "Failed to parse clipboard data: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func cleanupTemporaryReplayFile() {
        if let tempURL = temporaryReplayFileURL {
            try? FileManager.default.removeItem(at: tempURL)
            temporaryReplayFileURL = nil
        }
    }
    
    
    func stopReplay() {
        geoLogger?.stopUpdatingLocation()
        geoLogger = nil
        isReplaying = false
        replayProgress = 0.0
        replayCurrentTime = 0.0
        cleanupTemporaryReplayFile()
    }
    
    func refreshRecordings() {
        recordings = recordingManager.listRecordings()
    }
    
    func selectRecording(_ recording: RecordingInfo) {
        if selectedRecording?.id == recording.id {
            selectedRecording = nil
        } else {
            selectedRecording = recording
        }
    }
    
    func deleteRecording(_ recording: RecordingInfo) {
        do {
            try recordingManager.deleteRecording(name: recording.name)
            refreshRecordings()
            if selectedRecording?.id == recording.id {
                selectedRecording = nil
            }
        } catch {
            errorMessage = "Failed to delete recording: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func shareRecording(_ recording: RecordingInfo) {
        let url = recordingManager.exportRecording(name: recording.name)
        shareURL = url
        showShareSheet = true
    }
    
    func exportRecordingAsGPX(_ recording: RecordingInfo) {
        do {
            let gpxURL = try recordingManager.exportRecordingAsGPX(name: recording.name)
            shareURL = gpxURL
            showShareSheet = true
        } catch {
            errorMessage = "Failed to export as GPX: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Update location history
        if let location = locations.last {
            locationHistory.append(location)
            
            // Keep only last 1000 locations to avoid memory issues
            if locationHistory.count > 1000 {
                locationHistory.removeFirst(locationHistory.count - 1000)
            }
            
            if isRecording {
                recordedEventsCount += locations.count
            }
        }
        
        // Trigger UI update by updating geoLogger property
        // This ensures SwiftUI sees the change in computed property currentLocation
        if let logger = geoLogger {
            geoLogger = logger  // Trigger @Published update
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        
        if isRecording {
            stopRecording()
        } else if isReplaying {
            stopReplay()
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // Location updates paused (device likely stationary)
        // This is normal behavior to save battery
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        // Location updates resumed (device started moving)
    }
}

// MARK: - GeoLoggerDelegate

extension LocationViewModel: GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval) {
        replayProgress = progress
        replayCurrentTime = currentTime
    }
}
