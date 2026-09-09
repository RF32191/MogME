import Combine
import CoreLocation
import Foundation
import UIKit

/// Background-safe GPS. Location is recorded on a serial queue; SwiftUI only
/// gets a throttled snapshot while the app is in the foreground.
///
/// Crashes this avoids when the user leaves the app or multitasks:
/// 1. Publishing @Published / Map polylines from every Core Location callback
/// 2. Hopping to MainActor while SwiftUI is tearing a workout view down
/// 3. Deiniting the manager mid-callback (engine lives on AppState)
/// 4. Enabling background updates before Always authorization
/// 5. Force-unwrapping CLLocation copies
final class WorkoutLocationEngine: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isTracking = false
    @Published private(set) var lastPoint: GPSPoint?
    @Published private(set) var route: [GPSPoint] = []
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var currentSpeed: Double = 0
    @Published private(set) var statusMessage = "Location idle"

    private let manager = CLLocationManager()
    private let locationQueue = DispatchQueue(label: "com.mogme.location", qos: .utility)
    private let lock = NSLock()
    private var pendingStart = false
    private var stored: [GPSPoint] = []
    private var storedDistance: Double = 0
    private var storedLast: GPSPoint?
    private var publishWork: DispatchWorkItem?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 6
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = true
        manager.showsBackgroundLocationIndicator = true
        authorization = manager.authorizationStatus
    }

    deinit {
        manager.stopUpdatingLocation()
        manager.delegate = nil
        endBackgroundTask()
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
        publishOnMain { [weak self] in
            self?.authorization = status
        }
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            pendingStart = true
            publishOnMain { [weak self] in
                self?.statusMessage = "Allow location while using the app to track this workout."
            }
            return
        }
        pendingStart = false
        lock.lock()
        stored = []
        storedDistance = 0
        storedLast = nil
        lock.unlock()
        beginBackgroundTask()
        manager.pausesLocationUpdatesAutomatically = false
        if status == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
        publishOnMain { [weak self] in
            self?.isTracking = true
            self?.route = []
            self?.lastPoint = nil
            self?.distanceMeters = 0
            self?.currentSpeed = 0
            self?.statusMessage = "Acquiring GPS…"
        }
    }

    func stop() {
        pendingStart = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        endBackgroundTask()
        flushUI(force: true)
        publishOnMain { [weak self] in
            guard let self else { return }
            self.isTracking = false
            self.statusMessage = self.route.isEmpty ? "No GPS lock" : "Saved \(self.route.count) points"
        }
    }

    func snapshotRoute() -> [GPSPoint] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func snapshotDistance() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return storedDistance
    }

    private func ingest(_ locations: [CLLocation]) {
        lock.lock()
        var nextRoute = stored
        var nextDistance = storedDistance
        var latest = storedLast
        lock.unlock()

        var acceptedSpeed = latest?.speed ?? 0
        for location in locations {
            guard GPSFilter.accept(location, previous: latest?.clLocation) else { continue }
            let point = GPSPoint(location: location)
            if let previous = latest {
                nextDistance += GPSFilter.distance(from: previous, to: point)
            }
            nextRoute.append(point)
            latest = point
            acceptedSpeed = max(0, location.speed)
        }
        if nextRoute.count > 4_000 {
            nextRoute = Array(nextRoute.suffix(3_000))
        }
        lock.lock()
        stored = nextRoute
        storedDistance = nextDistance
        storedLast = latest
        lock.unlock()
        schedulePublish()
    }

    private func schedulePublish() {
        publishWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.flushUI(force: false)
        }
        publishWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private func flushUI(force: Bool) {
        let state = UIApplication.shared.applicationState
        if !force, state != .active { return }
        lock.lock()
        let points = stored
        let distance = storedDistance
        let last = storedLast
        lock.unlock()
        let preview = Self.downsample(points, max: 180)
        publishOnMain { [weak self] in
            guard let self else { return }
            self.route = preview
            self.distanceMeters = distance
            self.lastPoint = last
            self.currentSpeed = last?.speed ?? 0
            if let last {
                self.statusMessage = String(format: "GPS ±%.0fm", last.horizontalAccuracy)
            }
        }
    }

    static func downsample(_ points: [GPSPoint], max: Int) -> [GPSPoint] {
        guard points.count > max else { return points }
        let step = Double(points.count) / Double(max)
        var out: [GPSPoint] = []
        out.reserveCapacity(max)
        var i = 0.0
        while Int(i) < points.count, out.count < max - 1 {
            out.append(points[Int(i)])
            i += step
        }
        if let last = points.last { out.append(last) }
        return out
    }

    private func publishOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func beginBackgroundTask() {
        endBackgroundTask()
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "mogme.workout") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }
}

extension WorkoutLocationEngine: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.authorization = status
            if self.pendingStart, status == .authorizedAlways || status == .authorizedWhenInUse {
                self.start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let copies = locations.compactMap { $0.copy() as? CLLocation }
        guard !copies.isEmpty else { return }
        locationQueue.async { [weak self] in
            self?.ingest(copies)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = message
        }
    }
}
