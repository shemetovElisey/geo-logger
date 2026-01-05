import Foundation

/// Extensions to FileManager for GeoLogger-specific operations
public extension FileManager {

    /// Returns the URL to the GeoLogger directory in the app's document directory.
    /// Creates the directory if it doesn't exist.
    ///
    /// - Returns: URL to the GeoLogger directory
    /// - Throws: Error if directory creation fails
    func geoLoggerDirectory() throws -> URL {
        let documentDirectory = try url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let geoLoggerDir = documentDirectory.appendingPathComponent("GeoLogger")

        if !fileExists(atPath: geoLoggerDir.path) {
            try createDirectory(at: geoLoggerDir, withIntermediateDirectories: true)
        }

        return geoLoggerDir
    }

    /// Generates a unique recording file name with timestamp
    ///
    /// - Returns: A unique file name in the format "geo_log_YYYYMMDD_HHMMSS_UUID.geojson"
    static func generateRecordingFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let uuid = UUID().uuidString.prefix(8)

        return "geo_log_\(timestamp)_\(uuid).geojson"
    }
}
