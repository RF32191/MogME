import CoreLocation
import Foundation

struct GPSPoint: Hashable, Sendable, Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let speed: Double
    let horizontalAccuracy: Double
    let course: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }

    init(location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        timestamp = location.timestamp
        speed = max(0, location.speed)
        horizontalAccuracy = location.horizontalAccuracy
        course = location.course
    }
}

enum GPSFilter {
    /// Rejects the junk samples that used to crash / jump the Japanese-walk and interval maps:
    /// negative accuracy, stale caches, impossible teleports, and NaN coordinates.
    static func accept(_ next: CLLocation, previous: CLLocation?, now: Date = Date()) -> Bool {
        guard next.horizontalAccuracy >= 0, next.horizontalAccuracy <= 45 else { return false }
        guard next.coordinate.latitude.isFinite, next.coordinate.longitude.isFinite else { return false }
        guard abs(next.coordinate.latitude) <= 90, abs(next.coordinate.longitude) <= 180 else { return false }
        guard now.timeIntervalSince(next.timestamp) < 8 else { return false }
        if next.speed.isNaN || next.speed.isInfinite { return false }
        // Core Location uses a negative speed when speed is unavailable — that is fine.
        if let previous {
            let delta = next.distance(from: previous)
            let dt = next.timestamp.timeIntervalSince(previous.timestamp)
            if dt <= 0 { return false }
            // > 18 m/s (~40 mph) between walk/cardio samples is a GPS teleport.
            if delta / dt > 18 { return false }
            if delta < 0.6 && dt < 0.8 { return false }
        }
        return true
    }

    static func distance(from a: GPSPoint, to b: GPSPoint) -> CLLocationDistance {
        a.clLocation.distance(from: b.clLocation)
    }
}
