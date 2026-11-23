import Foundation
import CoreLocation

@MainActor
final class LocationCaptureManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationCaptureManager()
    static let preciseLocationPreferenceKey = "preciseExpenseLocationEnabled"

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    @Published var isPreciseLocationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPreciseLocationEnabled, forKey: Self.preciseLocationPreferenceKey)
        }
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isCapturing: Bool = false

    private override init() {
        self.isPreciseLocationEnabled = UserDefaults.standard.bool(forKey: Self.preciseLocationPreferenceKey)
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermissionIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            return nil
        }

        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        if let recent = manager.location, abs(recent.timestamp.timeIntervalSinceNow) < 30 {
            return recent.coordinate
        }

        isCapturing = true
        defer { isCapturing = false }

        return await withCheckedContinuation { continuation in
            self.continuation?.resume(returning: nil)
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        Task { @MainActor in
            self.continuation?.resume(returning: coord)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(returning: nil)
            self.continuation = nil
        }
    }
}
