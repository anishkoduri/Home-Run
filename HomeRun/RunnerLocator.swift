import CoreLocation
import SwiftUI

/// Asks for location only after the runner taps the control. Denial leaves the manual area in place.
final class RunnerLocator: NSObject, CLLocationManagerDelegate {
    static let shared = RunnerLocator()
    private let manager = CLLocationManager()
    var onFix: ((CLLocation) -> Void)?
    private override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else { return }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let fix = onFix
        Task { @MainActor in
            fix?(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
