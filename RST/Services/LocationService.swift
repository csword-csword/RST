import CoreLocation
import Foundation
import Observation

struct WorkoutLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var placeName: String?
}

/// One-shot location capture used to record where a workout took place.
/// The coordinate is reverse-geocoded to a place name (ideally the gym).
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private(set) var current: WorkoutLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        var result = WorkoutLocation(latitude: location.coordinate.latitude,
                                     longitude: location.coordinate.longitude,
                                     placeName: nil)
        current = result
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            result.placeName = placemark.name ?? placemark.locality
            DispatchQueue.main.async {
                self?.current = result
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location is best-effort; workouts save without it.
    }
}
