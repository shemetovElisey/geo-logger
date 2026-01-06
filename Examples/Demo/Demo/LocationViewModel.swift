//
//  LocationViewModel.swift
//  Demo
//
//  Created by Elisey Shemetov on 05.01.2026.
//

import SwiftUI
import Combine
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
    
    private var recordingManager = RecordingManager.shared
    private var recordingStartTime: Date?
    
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
        
        let logger = GeoLogger(configuration: config)
        logger.delegate = self  // Use standard CLLocationManagerDelegate
        logger.geoLoggerDelegate = self
        logger.requestWhenInUseAuthorization()
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
    
    func stopReplay() {
        geoLogger?.stopUpdatingLocation()
        geoLogger = nil
        isReplaying = false
        replayProgress = 0.0
        replayCurrentTime = 0.0
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
}

// MARK: - GeoLoggerDelegate

extension LocationViewModel: GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval) {
        replayProgress = progress
        replayCurrentTime = currentTime
    }
}

