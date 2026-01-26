import Foundation

/// Manages recording files (list, delete, export)
public final class RecordingManager {
    private let directory: URL

    /// Shared instance using default directory
    public static let shared = RecordingManager()

    /// Initialize with custom directory
    public init(directory: URL? = nil) {
        if let directory = directory {
            self.directory = directory
        } else {
            self.directory = (try? FileManager.default.geoLoggerDirectory(customDirectory: nil))
                ?? FileManager.default.temporaryDirectory
        }
    }

    /// List all recordings in directory
    public func listRecordings() -> [RecordingInfo] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" || $0.pathExtension == "geojson" }
            .compactMap { fileURL -> RecordingInfo? in
                guard let data = try? Data(contentsOf: fileURL),
                      let recordingFile = try? self.decodeRecordingFile(data),
                      let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                      let size = attributes[.size] as? Int64,
                      let creationDate = attributes[.creationDate] as? Date else {
                    return nil
                }

                return RecordingInfo(
                    name: fileURL.lastPathComponent,
                    date: creationDate,
                    size: size,
                    duration: recordingFile.metadata.duration,
                    eventCount: recordingFile.metadata.eventCount
                )
            }
            .sorted { $0.date > $1.date }
    }

    /// Delete a recording by name
    public func deleteRecording(name: String) throws {
        let fileURL = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw RecordingManagerError.recordingNotFound
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Get URL for sharing/exporting recording
    public func exportRecording(name: String) -> URL {
        return directory.appendingPathComponent(name)
    }
    
    /// Export recording to GPX format
    /// - Parameters:
    ///   - name: Name of the recording file (JSON)
    ///   - gpxFileName: Optional custom name for GPX file. If nil, uses original name with .gpx extension
    /// - Returns: URL of the exported GPX file
    /// - Throws: Error if recording file cannot be read or GPX file cannot be written
    public func exportRecordingAsGPX(name: String, gpxFileName: String? = nil) throws -> URL {
        // Load the recording file
        let jsonURL = directory.appendingPathComponent(name)
        let data = try Data(contentsOf: jsonURL)
        let recordingFile = try decodeRecordingFile(data)
        
        // Generate GPX file name
        let gpxName: String
        if let customName = gpxFileName {
            gpxName = customName.hasSuffix(".gpx") ? customName : "\(customName).gpx"
        } else {
            let baseName = (name as NSString).deletingPathExtension
            gpxName = "\(baseName).gpx"
        }
        
        // Export to GPX
        let gpxURL = directory.appendingPathComponent(gpxName)
        try GPXExporter.exportToGPX(recordingFile, to: gpxURL)
        
        return gpxURL
    }

    private func decodeRecordingFile(_ data: Data) throws -> RecordingFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RecordingFile.self, from: data)
    }
}

// MARK: - Errors

public enum RecordingManagerError: LocalizedError {
    case recordingNotFound
    
    public var errorDescription: String? {
        switch self {
        case .recordingNotFound:
            return "Recording not found"
        }
    }
}

