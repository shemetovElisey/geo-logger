import Foundation

/// Manages recording files (list, delete, export)
public final class RecordingManager {
    private let directory: URL

    /// Shared instance using default directory
    public static let shared = RecordingManager(directory: nil)

    /// Initialize with custom directory
    public init(directory: URL?) {
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
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Get URL for sharing/exporting recording
    public func exportRecording(name: String) -> URL {
        return directory.appendingPathComponent(name)
    }

    private func decodeRecordingFile(_ data: Data) throws -> RecordingFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RecordingFile.self, from: data)
    }
}

