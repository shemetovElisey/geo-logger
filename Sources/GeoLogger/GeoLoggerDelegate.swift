import Foundation
import CoreLocation

/// Delegate protocol for GeoLogger-specific events
/// 
/// For location updates and errors, use CLLocationManagerDelegate directly.
/// This delegate is only for GeoLogger-specific functionality like replay progress and recording progress.
public protocol GeoLoggerDelegate: AnyObject {
    /// Called when replay progress updates (only in replay mode)
    /// - Parameters:
    ///   - logger: The GeoLogger instance
    ///   - progress: Progress from 0.0 to 1.0
    ///   - currentTime: Current time in the recording (relative time from start)
    func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval)
    
    /// Called when a location is recorded (only in record mode)
    /// - Parameters:
    ///   - logger: The GeoLogger instance
    ///   - location: The recorded location
    ///   - index: The index of the recorded location (0-based, only location events are counted)
    func geoLogger(_ logger: GeoLogger, didRecordLocation location: CLLocation, atIndex index: Int)
}

// Make delegate methods optional
public extension GeoLoggerDelegate {
    func geoLogger(_ logger: GeoLogger, didUpdateReplayProgress progress: Double, currentTime: TimeInterval) {}
    func geoLogger(_ logger: GeoLogger, didRecordLocation location: CLLocation, atIndex index: Int) {}
}

