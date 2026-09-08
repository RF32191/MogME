import Combine
import CoreLocation
import Foundation

/// Thread-safe GPS session used by Japanese walking and interval cardio.
///
/// Crash sources this replaces:
/// 1. Updating `@Published` / SwiftUI maps from Core Location's callback thread
/// 2. Mutating the route array from the location queue while the UI reads it
/// 3. Starting updates before authorization is granted
/// 4. Retaining the location manager after the workout ends
/// 5. Applying every raw point (teleports) onto the map
@MainActor
final class WorkoutLocationEngine: NSObject, ObservableObject {
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isTracking = false
    @Published private(set) var lastPoint: GPSPoint?
    @Published private(set) var route: [GPSPoint] = []
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var currentSpeed: Double = 0
    @Published private(set) var statusMessage = "Location idle"

    private let manager = CLLocationManager()
    /// All Core Location callbacks land here — never hop onto the cooperative thread pool.
    private let locationQueue = DispatchQueue(label: "com.mogme.location", qos: .userInitiated)
    private var pendingStart = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 4
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            manager.allowsBackgroundLocationUpdates = true
        }
        authorization = manager.authorizationStatus
    }

    deinit {
        manager.stopUpdatingLocation()
        manager.delegate = nil
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func start() {
        requestPermission()
        let status = manager.authorizationStatus
        authorization = status
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            pendingStart = true
            statusMessage = "Allow location while using the app to track this workout."
            return
        }
        pendingStart = false
        route = []
        lastPoint = nil
        distanceMeters = 0
        currentSpeed = 0
        isTracking = true
        statusMessage = "Acquiring GPS…"
        manager.startUpdatingLocation()
    }

    func stop() {
        pendingStart = false
        isTracking = false
        manager.stopUpdatingLocation()
        statusMessage = route.isEmpty ? "No GPS lock" : "Saved \(route.count) points"
    }

    fileprivate func ingest(_ locations: [CLLocation]) {
        let accepted = locations.filter { GPSFilter.accept($0, previous: lastPoint?.clLocation) }
        guard !accepted.isEmpty else { return }

        var snapshotRoute = route
        var snapshotDistance = distanceMeters
        var latest = lastPoint

        for location in accepted {
            let point = GPSPoint(location: location)
            if let previous = latest {
                snapshotDistance += GPSFilter.distance(from: previous, to: point)
            }
            snapshotRoute.append(point)
            latest = point
        }

        // Cap memory so a 2-hour session cannot balloon and crash.
        if snapshotRoute.count > 8_000 {
            snapshotRoute = Array(snapshotRoute.suffix(6_000))
        }

        route = snapshotRoute
        lastPoint = latest
        distanceMeters = snapshotDistance
        currentSpeed = max(0, accepted.last?.speed ?? currentSpeed)
        statusMessage = String(format: "GPS ±%.0fm", accepted.last?.horizontalAccuracy ?? 0)
    }
}

extension WorkoutLocationEngine: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorization = status
            if self.pendingStart, status == .authorizedAlways || status == .authorizedWhenInUse {
                self.start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Copy values on the location queue, then publish on the main actor only.
        let copy = locations.map { $0.copy() as! CLLocation }
        Task { @MainActor [weak self] in
            self?.ingest(copy)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.statusMessage = error.localizedDescription
        }
    }
}
