import CoreLocation
import Foundation

/// Captures the user's current location and reverse-geocodes it to a
/// human-readable name (e.g. "Granary Wharf, Leeds" rather than
/// "53.7929°N, 1.5536°W"), per design.md §5.4. Uses CoreLocation with
/// the `whenInUse` permission only.
///
/// Wraps the delegate-based CLLocationManager API in async/await via
/// CheckedContinuation so callers can `try await captureCurrentPlace()`
/// and get back the coords + a display string.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    enum LocationError: Error {
        case permissionDenied
        case unavailable(Error?)
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// One-shot: ensure permission, fetch the current location, reverse-
    /// geocode it. Returns coords + display name on success, throws on
    /// permission denial or location unavailability. Returns plain
    /// Doubles instead of CLLocation so callers don't need to import
    /// CoreLocation.
    @MainActor
    func captureCurrentPlace() async throws -> (latitude: Double, longitude: Double, displayName: String) {
        let status = await ensureAuthorization()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw LocationError.permissionDenied
        }

        let location = try await requestOneShot()
        let name = await reverseGeocode(location)
        return (location.coordinate.latitude, location.coordinate.longitude, name)
    }

    /// Triggers the system permission prompt if status is .notDetermined
    /// and waits for the delegate callback. Otherwise returns the
    /// current status immediately.
    @MainActor
    private func ensureAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined { return current }
        return await withCheckedContinuation { cont in
            self.authContinuation = cont
            manager.requestWhenInUseAuthorization()
        }
    }

    @MainActor
    private func requestOneShot() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont
            manager.requestLocation()
        }
    }

    /// Best-effort reverse geocoding. Falls back to a "lat, lon" string
    /// if the geocoder is unhappy (network out, rate-limited, etc.).
    private func reverseGeocode(_ location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
           let placemark = placemarks.first,
           let name = formattedName(from: placemark) {
            return name
        }
        return defaultName(for: location)
    }

    /// Concatenates the most useful CLPlacemark fields into a short,
    /// human-readable string. design.md §5.4 wants "Granary Wharf, Leeds"
    /// — placemark.name + .locality usually gets us there.
    private func formattedName(from placemark: CLPlacemark) -> String? {
        var parts: [String] = []
        if let name = placemark.name, !name.isEmpty {
            parts.append(name)
        }
        if let locality = placemark.locality,
           !locality.isEmpty,
           !parts.contains(locality) {
            parts.append(locality)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func defaultName(for location: CLLocation) -> String {
        let lat = String(format: "%.4f", location.coordinate.latitude)
        let lon = String(format: "%.4f", location.coordinate.longitude)
        return "\(lat), \(lon)"
    }

    // MARK: - CLLocationManagerDelegate
    //
    // Delegate methods come in on the manager's queue (main, since we
    // configured the delegate from main). Wrap state mutations in
    // MainActor tasks anyway for thread-safety belt-and-braces.

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else {
                self.locationContinuation?.resume(throwing: LocationError.unavailable(nil))
                self.locationContinuation = nil
                return
            }
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(throwing: LocationError.unavailable(error))
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authContinuation?.resume(returning: manager.authorizationStatus)
            self.authContinuation = nil
        }
    }
}
