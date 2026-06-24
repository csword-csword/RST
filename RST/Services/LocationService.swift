import CoreLocation
import Foundation
import MapKit
import Observation

struct WorkoutLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var placeName: String?
}

/// One-shot location capture used to record where a workout took place, plus
/// MapKit points-of-interest lookup to auto-name the gym (and detect a known
/// chain so the builder can switch profiles automatically).
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var gymSearch: MKLocalSearch?
    private(set) var current: WorkoutLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// Gym-profile id of a recognized chain at the current location, if any.
    private(set) var detectedChainID: String?

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
        current = WorkoutLocation(latitude: location.coordinate.latitude,
                                  longitude: location.coordinate.longitude,
                                  placeName: nil)
        lookUpGym(near: location)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            // Only use the geocoded name if a gym POI hasn't already named it.
            DispatchQueue.main.async {
                if self.current?.placeName == nil {
                    self.current?.placeName = placemark.name ?? placemark.locality
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location is best-effort; workouts save without it.
    }

    /// Finds the nearest fitness center to the coordinate and names the workout
    /// after it, detecting a known chain when possible.
    private func lookUpGym(near location: CLLocation) {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 200)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.fitnessCenter])
        let search = MKLocalSearch(request: request)
        gymSearch = search  // retain until completion
        search.start { [weak self] response, _ in
            guard let self else { return }
            let nearest = response?.mapItems.min { a, b in
                (a.placemark.location?.distance(from: location) ?? .greatestFiniteMagnitude)
                    < (b.placemark.location?.distance(from: location) ?? .greatestFiniteMagnitude)
            }
            guard let name = nearest?.name else { return }
            DispatchQueue.main.async {
                self.current?.placeName = name
                self.detectedChainID = Self.chainID(for: name)
            }
        }
    }

    /// Maps a venue name to a bundled gym profile id, if it's a known chain.
    static func chainID(for name: String) -> String? {
        let n = name.lowercased()
        if n.contains("planet fitness") { return "planet-fitness" }
        if n.contains("la fitness") || n.contains("la-fitness") { return "la-fitness" }
        return nil
    }
}
