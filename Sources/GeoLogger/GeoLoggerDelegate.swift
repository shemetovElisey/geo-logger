import Foundation
import CoreLocation

/// Delegate protocol for GeoLogger events (mirrors CLLocationManagerDelegate)
public protocol GeoLoggerDelegate: AnyObject {
    /// Called when new locations are available
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation])

    /// Called when location manager fails with error
    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error)
}

// Make delegate methods optional
public extension GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {}
    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error) {}
}

