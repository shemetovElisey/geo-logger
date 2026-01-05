import Foundation
import CoreLocation

/// Utility for exporting recording files to GPX format
public enum GPXExporter {
    /// Convert RecordingFile to GPX XML string
    /// - Parameter recordingFile: The recording file to convert
    /// - Returns: GPX XML string
    public static func convertToGPX(_ recordingFile: RecordingFile) -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GeoLogger" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
            <metadata>
                <name>\(escapeXML(recordingFile.metadata.device))</name>
                <desc>Recorded on \(formatDate(recordingFile.metadata.recordedAt)) using \(recordingFile.metadata.systemVersion)</desc>
                <time>\(formatDateISO8601(recordingFile.metadata.recordedAt))</time>
            </metadata>
            <trk>
                <name>GeoLogger Track</name>
                <desc>Duration: \(formatDuration(recordingFile.metadata.duration)), Events: \(recordingFile.metadata.eventCount)</desc>
                <trkseg>
        
        """
        
        // Add track points from location events
        for event in recordingFile.events {
            switch event {
            case .location(_, _, let location):
                let lat = location.coordinate.latitude
                let lon = location.coordinate.longitude
                let ele = location.altitude
                let time = formatDateISO8601(location.timestamp)
                
                gpx += """
                        <trkpt lat="\(lat)" lon="\(lon)">
                            <ele>\(ele)</ele>
                            <time>\(time)</time>
                """
                
                // Add optional accuracy information as extensions
                if location.horizontalAccuracy >= 0 {
                    gpx += """
                            <extensions>
                                <horizontalAccuracy>\(location.horizontalAccuracy)</horizontalAccuracy>
                    """
                    if location.verticalAccuracy >= 0 {
                        gpx += """
                                <verticalAccuracy>\(location.verticalAccuracy)</verticalAccuracy>
                        """
                    }
                    if location.speed >= 0 {
                        gpx += """
                                <speed>\(location.speed)</speed>
                        """
                    }
                    if location.course >= 0 {
                        gpx += """
                                <course>\(location.course)</course>
                        """
                    }
                    gpx += """
                            </extensions>
                    """
                }
                
                gpx += """
                        </trkpt>
                
                """
            case .error:
                // Skip error events in GPX
                break
            }
        }
        
        gpx += """
                </trkseg>
            </trk>
        </gpx>
        """
        
        return gpx
    }
    
    /// Export recording file to GPX format
    /// - Parameters:
    ///   - recordingFile: The recording file to export
    ///   - outputURL: URL where to save the GPX file
    /// - Throws: Error if file writing fails
    public static func exportToGPX(_ recordingFile: RecordingFile, to outputURL: URL) throws {
        let gpxString = convertToGPX(recordingFile)
        guard let data = gpxString.data(using: .utf8) else {
            throw NSError(domain: "GPXExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode GPX string"])
        }
        try data.write(to: outputURL, options: .atomic)
    }
    
    // MARK: - Helper Methods
    
    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
    
    private static func formatDateISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    private static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

