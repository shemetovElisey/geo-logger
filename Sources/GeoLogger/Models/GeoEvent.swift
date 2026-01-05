import Foundation
import CoreLocation

/// Event in a recording (location update or error)
enum GeoEvent: Codable {
    case location(timestamp: Date, relativeTime: TimeInterval, location: CLLocation)
    case error(timestamp: Date, relativeTime: TimeInterval, error: Error)

    enum CodingKeys: String, CodingKey {
        case type, timestamp, relativeTime, data, code, domain, description
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .location(let timestamp, let relativeTime, let location):
            try container.encode("location", forKey: .type)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(relativeTime, forKey: .relativeTime)

            let locationData = try LocationData(location: location)
            try container.encode(locationData, forKey: .data)

        case .error(let timestamp, let relativeTime, let error):
            try container.encode("error", forKey: .type)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(relativeTime, forKey: .relativeTime)

            let nsError = error as NSError
            try container.encode(nsError.code, forKey: .code)
            try container.encode(nsError.domain, forKey: .domain)
            try container.encode(nsError.localizedDescription, forKey: .description)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let relativeTime = try container.decode(TimeInterval.self, forKey: .relativeTime)

        switch type {
        case "location":
            let locationData = try container.decode(LocationData.self, forKey: .data)
            let location = locationData.toCLLocation()
            self = .location(timestamp: timestamp, relativeTime: relativeTime, location: location)

        case "error":
            let code = try container.decode(Int.self, forKey: .code)
            let domain = try container.decode(String.self, forKey: .domain)
            let description = try container.decode(String.self, forKey: .description)
            let error = NSError(domain: domain, code: code, userInfo: [
                NSLocalizedDescriptionKey: description
            ])
            self = .error(timestamp: timestamp, relativeTime: relativeTime, error: error)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown event type: \(type)"
            )
        }
    }
}

/// Codable representation of CLLocation
private struct LocationData: Codable {
    let coordinate: CoordinateData
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let course: Double
    let courseAccuracy: Double
    let speed: Double
    let speedAccuracy: Double
    let floor: Int?
    let timestamp: Date
    let ellipsoidalAltitude: Double?
    let sourceInformation: SourceInformationData?

    struct CoordinateData: Codable {
        let latitude: Double
        let longitude: Double
    }

    struct SourceInformationData: Codable {
        let isSimulatedBySoftware: Bool
        let isProducedByAccessory: Bool
    }

    init(location: CLLocation) throws {
        self.coordinate = CoordinateData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.course = location.course
        if #available(iOS 13.4, macOS 10.15.4, *) {
            self.courseAccuracy = location.courseAccuracy
        } else {
            self.courseAccuracy = -1
        }
        self.speed = location.speed
        if #available(iOS 10.0, macOS 10.15, *) {
            self.speedAccuracy = location.speedAccuracy
        } else {
            self.speedAccuracy = -1
        }
        if #available(iOS 8.0, macOS 10.15, *) {
            self.floor = location.floor?.level
        } else {
            self.floor = nil
        }
        self.timestamp = location.timestamp

        if #available(iOS 15.0, macOS 12.0, *) {
            self.ellipsoidalAltitude = location.ellipsoidalAltitude
            self.sourceInformation = location.sourceInformation.map {
                SourceInformationData(
                    isSimulatedBySoftware: $0.isSimulatedBySoftware,
                    isProducedByAccessory: $0.isProducedByAccessory
                )
            }
        } else {
            self.ellipsoidalAltitude = nil
            self.sourceInformation = nil
        }
    }

    /// Converts LocationData back to CLLocation
    ///
    /// Note: Due to CLLocation API limitations, some properties cannot be restored:
    /// - `courseAccuracy`, `speedAccuracy` (no public initializer accepts these)
    /// - `floor` information (read-only property)
    /// - `ellipsoidalAltitude`, `sourceInformation` (iOS 15+ read-only properties)
    ///
    /// The restored CLLocation contains the essential navigation properties:
    /// coordinate, altitude, course, speed, horizontal/vertical accuracy, and timestamp.
    /// This is acceptable for the replay use case where coordinates, altitude, speed,
    /// and timestamp are critical, while metadata like courseAccuracy is less important.
    func toCLLocation() -> CLLocation {
        let coordinate = CLLocationCoordinate2D(
            latitude: self.coordinate.latitude,
            longitude: self.coordinate.longitude
        )

        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}
