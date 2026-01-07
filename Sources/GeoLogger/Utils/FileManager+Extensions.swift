import Foundation

extension FileManager {
    /// Get or create the GeoLogger directory
    /// - Parameter customDirectory: Optional custom directory, defaults to Documents/GeoLogger
    /// - Returns: URL of the directory
    public func geoLoggerDirectory(customDirectory: URL?) throws -> URL {
        let directory: URL

        if let customDirectory = customDirectory {
            directory = customDirectory
        } else {
            let documentsDirectory = try self.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directory = documentsDirectory.appendingPathComponent("GeoLogger", isDirectory: true)
        }

        // Create directory if it doesn't exist
        if !fileExists(atPath: directory.path) {
            try createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    /// Generate a unique recording file name with timestamp
    static func generateRecordingFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.timeZone = TimeZone.current
        let timestamp = formatter.string(from: Date())
        return "geo_log_\(timestamp).json"
    }
}
