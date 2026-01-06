//
//  ContentView.swift
//  Demo
//
//  Created by Elisey Shemetov on 05.01.2026.
//

import SwiftUI
import MapKit
import CoreLocation
import GeoLogger

struct ContentView: View {
    @StateObject private var viewModel = LocationViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map Section
                MapViewRepresentable(
                    region: $region,
                    currentLocation: viewModel.currentLocation,
                    locationHistory: viewModel.locationHistory,
                    isRecording: viewModel.isRecording,
                    isReplaying: viewModel.isReplaying
                )
                .frame(height: 350)
                .onChange(of: viewModel.currentLocation) { oldLocation, newLocation in
                    if let location = newLocation {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            // Keep current span if it exists, otherwise use default 0.01
                            let currentSpan = region.span
                            let span: MKCoordinateSpan
                            if oldLocation == nil {
                                // First location - use default span
                                span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            } else {
                                // Keep current span to preserve user's zoom level
                                span = currentSpan
                            }
                            
                            region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: span
                            )
                        }
                    }
                }
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Status Section
                        VStack(spacing: 10) {
                            if let location = viewModel.currentLocation {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Current Location:")
                                        .font(.headline)
                                    Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")
                                    Text("Lon: \(location.coordinate.longitude, specifier: "%.6f")")
                                    Text("Accuracy: \(location.horizontalAccuracy, specifier: "%.1f")m")
                                    if location.speed >= 0 {
                                        Text("Speed: \(location.speed * 3.6, specifier: "%.1f") km/h")
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            } else {
                                Text("No location data")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                        .padding()
                
                Divider()
                
                // Recording Section
                VStack(spacing: 15) {
                    Text("Recording")
                        .font(.headline)
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            viewModel.startRecording()
                        }) {
                            HStack {
                                Image(systemName: "record.circle")
                                Text("Start Recording")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isRecording ? Color.gray : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.isRecording || viewModel.isReplaying)
                        
                        Button(action: {
                            viewModel.stopRecording()
                        }) {
                            HStack {
                                Image(systemName: "stop.circle")
                                Text("Stop Recording")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isRecording ? Color.red : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!viewModel.isRecording)
                    }
                    
                    if viewModel.isRecording {
                        Text("Recording... \(viewModel.recordedEventsCount) events")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
                
                Divider()
                
                // Recordings List
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Recordings")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            viewModel.refreshRecordings()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    
                    if viewModel.recordings.isEmpty {
                        Text("No recordings yet")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        List {
                            ForEach(viewModel.recordings, id: \.name) { recording in
                                RecordingRow(
                                    recording: recording,
                                    isSelected: viewModel.selectedRecording?.name == recording.name,
                                    onSelect: {
                                        viewModel.selectRecording(recording)
                                    },
                                    onDelete: {
                                        viewModel.deleteRecording(recording)
                                    },
                                    onShare: {
                                        viewModel.shareRecording(recording)
                                    },
                                    onExportGPX: {
                                        viewModel.exportRecordingAsGPX(recording)
                                    }
                                )
                            }
                        }
                        .frame(height: 200)
                    }
                }
                .padding()
                
                Divider()
                
                // Replay Section
                VStack(spacing: 15) {
                    Text("Replay")
                        .font(.headline)
                    
                    if let selectedRecording = viewModel.selectedRecording {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected: \(selectedRecording.name)")
                                .font(.caption)
                            Text("Duration: \(selectedRecording.duration, specifier: "%.1f")s")
                                .font(.caption)
                            Text("Events: \(selectedRecording.eventCount)")
                                .font(.caption)
                            
                            // Progress bar
                            if viewModel.isReplaying {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Progress: \(Int(viewModel.replayProgress * 100))%")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(formatTime(viewModel.replayCurrentTime) + " / " + formatTime(selectedRecording.duration))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    ProgressView(value: viewModel.replayProgress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            viewModel.startReplay()
                        }) {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Start Replay")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isReplaying || viewModel.selectedRecording == nil ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.isReplaying || viewModel.selectedRecording == nil || viewModel.isRecording)
                        
                        Button(action: {
                            viewModel.stopReplay()
                        }) {
                            HStack {
                                Image(systemName: "stop.circle")
                                Text("Stop Replay")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isReplaying ? Color.red : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!viewModel.isReplaying)
                    }
                    
                    // Speed multiplier
                    VStack(alignment: .leading) {
                        Text("Replay Speed: \(viewModel.replaySpeed, specifier: "%.1f")x")
                            .font(.caption)
                        Slider(value: $viewModel.replaySpeed, in: 0.5...10.0, step: 0.5)
                    }
                    .padding(.horizontal)
                }
                .padding()
                
                    }
                }
            }
            .navigationTitle("GeoLogger")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let shareURL = viewModel.shareURL {
                    ShareSheet(activityItems: [shareURL])
                }
            }
        }
    }
}

struct RecordingRow: View {
    let recording: RecordingInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    let onExportGPX: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text("\(recording.duration, specifier: "%.1f")s")
                    Text("•")
                    Text("\(recording.eventCount) events")
                    Text("•")
                    Text(formatSize(recording.size))
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Menu {
                Button(action: onShare) {
                    Label("Share JSON", systemImage: "square.and.arrow.up")
                }
                Button(action: onExportGPX) {
                    Label("Export as GPX", systemImage: "map")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Helper function to format time
private func formatTime(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
}
