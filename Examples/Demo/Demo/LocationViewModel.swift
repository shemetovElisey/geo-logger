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
    @Published var currentLocation: CLLocation?
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
    
    private var geoLogger: GeoLogger?
    private var recordingManager = RecordingManager.shared
    private var recordingStartTime: Date?
    
    
    override init() {
        super.init()
        refreshRecordings()
    }
    
    func startRecording() {
        var config = GeoLoggerConfiguration()
        config.mode = .record
        
        geoLogger = GeoLogger(configuration: config)
        geoLogger?.delegate = self
        geoLogger?.requestWhenInUseAuthorization()
        geoLogger?.startUpdatingLocation()
        
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
        
        geoLogger = GeoLogger(configuration: config)
        geoLogger?.delegate = self
        geoLogger?.startUpdatingLocation()
        
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

extension LocationViewModel: GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
            locationHistory.append(location)
            
            // Keep only last 1000 locations to avoid memory issues
            if locationHistory.count > 1000 {
                locationHistory.removeFirst(locationHistory.count - 1000)
            }
            
            if isRecording {
                recordedEventsCount += locations.count
            }
        }
    }
    
    func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval) {
        replayProgress = progress
        replayCurrentTime = currentTime
    }
    
    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        
        if isRecording {
            stopRecording()
        } else if isReplaying {
            stopReplay()
        }
    }
}

