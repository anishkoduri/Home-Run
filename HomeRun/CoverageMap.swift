import MapKit
import SwiftUI

/// Cities Home Run covers, plus runners who have posted a trip. This is not live GPS.
struct CoverageMap: View {
    var trips: [Trip]

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.05, longitude: -97.15),
            span: MKCoordinateSpan(latitudeDelta: 5.4, longitudeDelta: 6.2)
        )
    }

    /// Major cities on the coverage map. Smaller origins stay in the city picker.
    private var majorCities: [City] {
        ["Houston", "Dallas", "Austin", "San Antonio", "Fort Worth", "Waco", "College Station"].compactMap { Places.city(named: $0) }
    }

    private var posted: [Trip] {
        trips.filter { $0.status == "scheduled" || $0.status == "requests_closed" }
    }

    /// Nudge extra runners in the same city so two pins do not sit on top of each other.
    private func runnerSpot(_ trip: Trip) -> CLLocationCoordinate2D {
        let peers = posted.filter { $0.originCity == trip.originCity }.sorted { $0.id < $1.id }
        let index = peers.firstIndex { $0.id == trip.id } ?? 0
        guard index > 0 else {
            return CLLocationCoordinate2D(latitude: trip.originLat, longitude: trip.originLng)
        }
        let angle = Double(index) * 2.2
        return CLLocationCoordinate2D(
            latitude: trip.originLat + cos(angle) * 0.42,
            longitude: trip.originLng + sin(angle) * 0.42
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where we cover")
                .font(Theme.section())
                .foregroundStyle(Theme.maroon)
            Map(position: .constant(.region(region))) {
                ForEach(majorCities) { city in
                    Marker(city.name, systemImage: city.name == "College Station" ? "house.fill" : "mappin", coordinate: CLLocationCoordinate2D(latitude: city.lat, longitude: city.lng))
                        .tint(city.name == "College Station" ? Theme.ink : Theme.maroon)
                }
                ForEach(posted) { trip in
                    Annotation(trip.driver?.displayName ?? "Runner", coordinate: runnerSpot(trip)) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(Theme.text(.title2))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Theme.maroon)
                            .accessibilityLabel("Runner in \(trip.originCity)")
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 280)
            .mapFrame()
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("coverage-map")
            .accessibilityLabel("Map of Texas cities Home Run covers and runners with posted trips")
        }
    }
}

/// Simulated position along the posted pickup and drop-off. It is not the runner's phone.
struct DriverTrackMap: View {
    var order: Order
    @State private var position: MapCameraPosition

    init(order: Order) {
        self.order = order
        _position = State(initialValue: .region(Self.region(for: order)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live")
                .font(Theme.section())
                .foregroundStyle(Theme.ink)
            TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
                let fraction = Self.fraction(order: order, date: timeline.date)
                let runner = Self.point(order: order, fraction: fraction)
                Map(position: $position) {
                    Marker("Pickup", systemImage: "bag", coordinate: Self.pickup(order))
                        .tint(Theme.ink)
                    Marker("Drop-off", systemImage: "flag", coordinate: Self.dropoff(order))
                        .tint(Theme.maroon)
                    Annotation("Runner", coordinate: runner) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(Theme.text(.title))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Theme.maroon)
                    }
                    MapPolyline(coordinates: [Self.pickup(order), Self.dropoff(order)])
                        .stroke(Theme.maroon, lineWidth: 3)
                }
                .mapStyle(.standard(elevation: .flat))
            }
                .frame(height: 280)
            .mapFrame()
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("driver-track")
            .accessibilityLabel("Simulated map of your runner between the pickup and the drop-off")
            Text("Simulated. This phone is not sending GPS.")
                .font(Theme.text(.caption))
                .foregroundStyle(Theme.muted)
        }
    }

    private static func pickup(_ order: Order) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: order.restaurantLat, longitude: order.restaurantLng)
    }

    private static func dropoff(_ order: Order) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: order.destinationLat, longitude: order.destinationLng)
    }

    private static func region(for order: Order) -> MKCoordinateRegion {
        let pickup = pickup(order)
        let dropoff = dropoff(order)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (pickup.latitude + dropoff.latitude) / 2, longitude: (pickup.longitude + dropoff.longitude) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max(abs(pickup.latitude - dropoff.latitude) * 1.6, 0.08),
                longitudeDelta: max(abs(pickup.longitude - dropoff.longitude) * 1.6, 0.08)
            )
        )
    }

    private static func fraction(order: Order, date: Date) -> Double {
        let base: Double
        switch order.status {
        case .pickedUp: base = 0.28
        case .onTheWay: base = 0.58
        case .arriving: base = 0.86
        case .delivered: base = 1
        default: base = 0.08
        }
        if order.status == .delivered { return 1 }
        let travel = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 16) / 16 * 0.18
        return min(0.96, max(0, base + travel))
    }

    private static func point(order: Order, fraction: Double) -> CLLocationCoordinate2D {
        let pickup = pickup(order)
        let dropoff = dropoff(order)
        return CLLocationCoordinate2D(
            latitude: pickup.latitude + (dropoff.latitude - pickup.latitude) * fraction,
            longitude: pickup.longitude + (dropoff.longitude - pickup.longitude) * fraction
        )
    }
}
