import Foundation
import GoogleMaps

/// Reads Google keys from the built Info.plist. Values come from Config/Local.xcconfig at build time.
/// This type never prints a key.
enum GoogleCredentials {
    static var mapsSDKKey: String? { stored("GOOGLE_MAPS_IOS_API_KEY") ?? legacy }
    static var placesKey: String? { stored("GOOGLE_PLACES_API_KEY") ?? legacy }
    static var routesKey: String? { stored("GOOGLE_ROUTES_API_KEY") ?? legacy }

    /// Sanitized status for developer settings. No key material.
    static var developerStatus: String {
        "Maps SDK \(mapsSDKKey == nil ? "missing" : "configured"); Places \(placesKey == nil ? "missing" : "configured"); Routes \(routesKey == nil ? "missing" : "configured")"
    }

    private static var legacy: String? { stored("GOOGLE_MAPS_API_KEY") }

    private static func stored(_ name: String) -> String? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: name) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.count >= 20, !raw.contains(where: \.isWhitespace), !raw.contains("$"), !raw.contains("/") else { return nil }
        return raw
    }
}

enum GoogleMapsStartup {
    private(set) static var isReady = false

    /// Call once on the main thread before any map view. Missing keys leave the existing map in place.
    static func start() {
        guard !isReady, let key = GoogleCredentials.mapsSDKKey else { return }
        guard GMSServices.provideAPIKey(key) else { return }
        isReady = true
    }
}
