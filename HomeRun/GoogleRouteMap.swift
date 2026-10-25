import GoogleMaps
import SwiftUI

/// Google map tiles for a path the app already has. Created only after the Maps SDK key is accepted.
struct GoogleRouteMap: UIViewRepresentable {
    var path: [[Double]]

    func makeUIView(context: Context) -> GMSMapView {
        let map = GMSMapView()
        map.isMyLocationEnabled = false
        map.settings.myLocationButton = false
        map.settings.compassButton = false
        map.accessibilityLabel = "Map of the delivery route"
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        map.clear()
        let coordinates = path.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count == 2, abs(pair[0]) <= 90, abs(pair[1]) <= 180 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
        guard let first = coordinates.first else { return }
        let line = GMSMutablePath()
        coordinates.forEach { line.add($0) }
        if coordinates.count >= 2 {
            let overlay = GMSPolyline(path: line)
            overlay.strokeWidth = 4
            overlay.strokeColor = UIColor(red: 80 / 255, green: 20 / 255, blue: 32 / 255, alpha: 1)
            overlay.map = map
            map.moveCamera(GMSCameraUpdate.fit(GMSCoordinateBounds(path: line), withPadding: 32))
        } else {
            map.camera = GMSCameraPosition(target: first, zoom: 12)
        }
        for coordinate in coordinates {
            let marker = GMSMarker(position: coordinate)
            marker.map = map
        }
    }
}
