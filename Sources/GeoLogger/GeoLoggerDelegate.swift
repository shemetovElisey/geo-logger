import Foundation
import CoreLocation

/// Delegate protocol for GeoLogger events (mirrors CLLocationManagerDelegate)
public protocol GeoLoggerDelegate: AnyObject {
    /// Called when new locations are available
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation])

    /// Called when location manager fails with error
    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error)
    
    /// Called when replay progress updates (only in replay mode)
    /// - Parameters:
    ///   - logger: The GeoLogger instance
    ///   - progress: Progress from 0.0 to 1.0
    ///   - currentTime: Current time in the recording (relative time from start)
    func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval)
}

// Make delegate methods optional
public extension GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateLocations locations: [CLLocation]) {}
    func geoLogger(_ logger: GeoLogger, didFailWithError error: Error) {}
    func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval) {}
}

