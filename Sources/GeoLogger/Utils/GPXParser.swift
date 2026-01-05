import Foundation
import CoreLocation

/// Utility for parsing GPX files and converting them to RecordingFile format
public enum GPXParser {
    /// Parse GPX file and convert to RecordingFile
    /// - Parameter fileURL: URL of the GPX file
    /// - Returns: RecordingFile with parsed track data
    /// - Throws: Error if file cannot be read or parsed
    public static func parseGPX(from fileURL: URL) throws -> RecordingFile {
        let data = try Data(contentsOf: fileURL)
        return try parseGPX(from: data)
    }
    
    /// Parse GPX data and convert to RecordingFile
    /// - Parameter data: GPX file data
    /// - Returns: RecordingFile with parsed track data
    /// - Throws: Error if data cannot be parsed
    public static func parseGPX(from data: Data) throws -> RecordingFile {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "GPXParser", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode GPX file as UTF-8"
            ])
        }
        
        return try parseGPXString(xmlString)
    }
    
    /// Parse GPX XML string and convert to RecordingFile
    /// - Parameter xmlString: GPX XML content
    /// - Returns: RecordingFile with parsed track data
    /// - Throws: Error if XML cannot be parsed
    public static func parseGPXString(_ xmlString: String) throws -> RecordingFile {
        // Simple XML parsing using regex and string operations
        // For production, consider using XMLParser or a proper XML library
        
        var events: [GeoEvent] = []
        var recordedAt: Date?
        var device: String = "Unknown"
        var systemVersion: String = "Unknown"
        
        // Extract metadata
        if let timeMatch = xmlString.range(of: #"<time>([^<]+)</time>"#, options: [.regularExpression]) {
            let timeString = String(xmlString[timeMatch])
            if let timeRange = timeString.range(of: #">([^<]+)<"#, options: [.regularExpression]) {
                let extracted = String(timeString[timeRange])
                let iso8601String = String(extracted.dropFirst().dropLast())
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                recordedAt = formatter.date(from: iso8601String)
            }
        }
        
        if let nameMatch = xmlString.range(of: #"<name>([^<]+)</name>"#, options: [.regularExpression]) {
            let nameString = String(xmlString[nameMatch])
            if let nameRange = nameString.range(of: #">([^<]+)<"#, options: [.regularExpression]) {
                let extracted = String(nameString[nameRange])
                device = String(extracted.dropFirst().dropLast())
            }
        }
        
        // Extract track points
        let trkptPattern = #"<trkpt\s+lat="([^"]+)"\s+lon="([^"]+)"[^>]*>(.*?)</trkpt>"#
        let regex = try NSRegularExpression(pattern: trkptPattern, options: NSRegularExpression.Options.dotMatchesLineSeparators)
        let nsString = xmlString as NSString
        let matches = regex.matches(in: xmlString, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var startTime: Date?
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            
            let latRange = Range(match.range(at: 1), in: xmlString)!
            let lonRange = Range(match.range(at: 2), in: xmlString)!
            let contentRange = Range(match.range(at: 3), in: xmlString)!
            
            guard let lat = Double(String(xmlString[latRange])),
                  let lon = Double(String(xmlString[lonRange])) else {
                continue
            }
            
            let content = String(xmlString[contentRange])
            
            // Extract elevation
            var altitude: Double = 0.0
            if let eleMatch = content.range(of: #"<ele>([^<]+)</ele>"#, options: [.regularExpression]) {
                let eleString = String(content[eleMatch])
                if let eleValueRange = eleString.range(of: #">([^<]+)<"#, options: [.regularExpression]) {
                    let extracted = String(eleString[eleValueRange])
                    if let eleValue = Double(String(extracted.dropFirst().dropLast())) {
                        altitude = eleValue
                    }
                }
            }
            
            // Extract time
            var timestamp: Date?
            if let timeMatch = content.range(of: #"<time>([^<]+)</time>"#, options: [.regularExpression]) {
                let timeString = String(content[timeMatch])
                if let timeValueRange = timeString.range(of: #">([^<]+)<"#, options: [.regularExpression]) {
                    let extracted = String(timeString[timeValueRange])
                    let iso8601String = String(extracted.dropFirst().dropLast())
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    timestamp = formatter.date(from: iso8601String)
                }
            }
            
            // Extract extensions (accuracy, speed, course)
            var horizontalAccuracy: Double = -1
            var verticalAccuracy: Double = -1
            var speed: Double = -1
            var course: Double = -1
            
            let extensionsPattern = #"<extensions>(.*?)</extensions>"#
            if let extensionsRegex = try? NSRegularExpression(pattern: extensionsPattern, options: NSRegularExpression.Options.dotMatchesLineSeparators) {
                let contentNS = content as NSString
                let extensionsMatches = extensionsRegex.matches(in: content, options: [], range: NSRange(location: 0, length: contentNS.length))
                if let firstMatch = extensionsMatches.first, firstMatch.numberOfRanges > 1 {
                    let extensionsRange = Range(firstMatch.range(at: 1), in: content)!
                    let extensions = String(content[extensionsRange])
                    
                    if let accMatch = extensions.range(of: #"<horizontalAccuracy>([^<]+)</horizontalAccuracy>"#, options: [.regularExpression]) {
                        let accString = String(extensions[accMatch])
                        if let accValueRange = accString.range(of: #">([^<]+)<"#, options: [.regularExpression]) {
                            let extracted = String(accString[accValueRange])
                            horizontalAccuracy = Double(String(extracted.dropFirst().dropLast())) ?? -1
                        }
                    }
                    
                    if let vAccMatch = extensions.range(of: #"<verticalAccuracy>([^<]+)</verticalAccuracy>"#, options: [.regularExpression]) {
                        let vAccString = String(extensions[vAccMatch])
                        if let vAccValueRange = vAccString.range(of: #">([^<]+)<"#, options: [.regularExpression]) {
                            let extracted = String(vAccString[vAccValueRange])
                            verticalAccuracy = Double(String(extracted.dropFirst().dropLast())) ?? -1
                        }
                    }
                    
                    if let speedMatch = extensions.range(of: #"<speed>([^<]+)</speed>"#, options: [.regularExpression]) {
                        let speedString = String(extensions[speedMatch])
                        if let speedValueRange = speedString.range(of: #">([^<]+)<"#, options: [.regularExpression]) {
                            let extracted = String(speedString[speedValueRange])
                            speed = Double(String(extracted.dropFirst().dropLast())) ?? -1
                        }
                    }
                    
                    if let courseMatch = extensions.range(of: #"<course>([^<]+)</course>"#, options: [.regularExpression]) {
                        let courseString = String(extensions[courseMatch])
                        if let courseValueRange = courseString.range(of: #">([^<]+)<"#, options: [.regularExpression]) {
                            let extracted = String(courseString[courseValueRange])
                            course = Double(String(extracted.dropFirst().dropLast())) ?? -1
                        }
                    }
                }
            }
            
            // Use current time if timestamp not found
            let finalTimestamp = timestamp ?? Date()
            if startTime == nil {
                startTime = finalTimestamp
            }
            
            // Create CLLocation
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let location = CLLocation(
                coordinate: coordinate,
                altitude: altitude,
                horizontalAccuracy: horizontalAccuracy >= 0 ? horizontalAccuracy : kCLLocationAccuracyBest,
                verticalAccuracy: verticalAccuracy >= 0 ? verticalAccuracy : kCLLocationAccuracyBest,
                course: course >= 0 ? course : -1,
                speed: speed >= 0 ? speed : -1,
                timestamp: finalTimestamp
            )
            
            // Calculate relative time
            let relativeTime = startTime.map { finalTimestamp.timeIntervalSince($0) } ?? 0.0
            
            let event = GeoEvent.location(
                timestamp: finalTimestamp,
                relativeTime: relativeTime,
                location: location
            )
            events.append(event)
        }
        
        // Create metadata
        let finalRecordedAt = recordedAt ?? startTime ?? Date()
        let duration = events.last.map { $0.relativeTime } ?? 0.0
        
        let metadata = RecordingMetadata(
            version: "1.0",
            recordedAt: finalRecordedAt,
            device: device,
            systemVersion: systemVersion,
            duration: duration,
            eventCount: events.count
        )
        
        return RecordingFile(metadata: metadata, events: events)
    }
}

