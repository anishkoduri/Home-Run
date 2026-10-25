import SwiftUI
import UIKit

struct HomePlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let shoulder = rect.minY + rect.height * 0.62
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: shoulder))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: shoulder))
        path.closeSubpath()
        return path
    }
}

struct FoodPlate: View {
    @ScaledMetric(relativeTo: .title3) private var side = 96

    var body: some View {
        Group {
            if UIImage(named: "FoodPlate") != nil {
                Image("FoodPlate")
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.maroonDark
                    Image(systemName: "bag.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(HomePlateShape())
        .accessibilityHidden(true)
    }
}

struct PlateSketch: View {
    var body: some View {
        ZStack {
            HomePlateShape().fill(Theme.maroon)
            Image(systemName: "bag.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .offset(y: -8)
                .accessibilityHidden(true)
        }
        .frame(width: 76, height: 76)
        .accessibilityHidden(true)
    }
}

struct CityRoute: View {
    var origin: String
    var destination: String
    var tint: Color = Theme.maroon

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(origin)
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            RouteDash(tint: tint)
            Text(destination)
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(origin) to \(destination)")
    }
}

struct RouteDash: View {
    var tint: Color = Theme.maroon

    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Rectangle()
                .fill(tint.opacity(0.45))
                .frame(height: 2)
                .frame(maxWidth: 56)
            Circle().stroke(tint, lineWidth: 2).frame(width: 7, height: 7)
        }
        .frame(minWidth: 36)
        .accessibilityHidden(true)
    }
}

/// Posted cities only. This is not a live map and not a routed road path.
struct RouteSketch: View {
    var origin: String
    var destination: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FROM").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Text(origin).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TO").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Text(destination).font(.title3.weight(.bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.trailing)
                }
            }
            RouteDash()
                .frame(maxWidth: .infinity)
            Text("Posted cities only. The road route and fee appear after you choose a place. Home Run does not track the car.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TripSummary: View {
    var trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CityRoute(origin: trip.originCity, destination: trip.destinationCity)
            Text(Format.relative(trip.departureAt))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text(spotLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            if let name = Format.personalName(trip.driver?.displayName) {
                Text(name).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spotLine: String {
        let taken = trip.activeOrders ?? 0
        let open = max(0, trip.maxOrders - taken)
        if open == 0 { return "No spots left · \(taken) of \(trip.maxOrders)" }
        return "\(open) of \(trip.maxOrders) spots open"
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
    }
}
