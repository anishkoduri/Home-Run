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

/// A slightly wobbled panel edge, stable across frames.
struct InkCard: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 14, y: rect.minY + 3))
        path.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.minY + 1))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 1, y: rect.minY + 18), control: CGPoint(x: rect.maxX + 4, y: rect.minY - 3))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.maxY - 16))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 18, y: rect.maxY - 1), control: CGPoint(x: rect.maxX + 3, y: rect.maxY + 4))
        path.addLine(to: CGPoint(x: rect.minX + 16, y: rect.maxY - 2))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 1, y: rect.maxY - 16), control: CGPoint(x: rect.minX - 4, y: rect.maxY + 2))
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.minY + 16))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 14, y: rect.minY + 3), control: CGPoint(x: rect.minX - 3, y: rect.minY - 2))
        path.closeSubpath()
        _ = w
        _ = h
        return path
    }
}

struct GroceryBagSketch: View {
    var ink: Color = Theme.maroon

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var bag = Path()
            bag.move(to: CGPoint(x: w * 0.16, y: h * 0.38))
            bag.addLine(to: CGPoint(x: w * 0.84, y: h * 0.36))
            bag.addLine(to: CGPoint(x: w * 0.74, y: h * 0.94))
            bag.addLine(to: CGPoint(x: w * 0.24, y: h * 0.96))
            bag.closeSubpath()
            context.stroke(bag, with: .color(ink), lineWidth: 1.7)
            var fold = Path()
            fold.move(to: CGPoint(x: w * 0.18, y: h * 0.48))
            fold.addLine(to: CGPoint(x: w * 0.82, y: h * 0.46))
            context.stroke(fold, with: .color(ink), lineWidth: 1.2)
            func handle(from x0: CGFloat, to x1: CGFloat) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: x0, y: h * 0.38))
                path.addQuadCurve(to: CGPoint(x: x1, y: h * 0.36), control: CGPoint(x: (x0 + x1) / 2, y: h * 0.08))
                return path
            }
            context.stroke(handle(from: w * 0.28, to: w * 0.42), with: .color(ink), lineWidth: 1.6)
            context.stroke(handle(from: w * 0.56, to: w * 0.72), with: .color(ink), lineWidth: 1.6)
        }
        .frame(width: 52, height: 48)
        .accessibilityHidden(true)
    }
}

struct FoodPlate: View {
    @ScaledMetric(relativeTo: .title3) private var side = 112

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
                        .font(Theme.text(.title2))
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
                .font(Theme.text(.title3))
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
                .font(Theme.text(.headline, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            RouteDash(tint: tint)
            Text(destination)
                .font(Theme.text(.headline, weight: .semibold))
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
                    Text("FROM").font(Theme.text(.caption, weight: .bold)).foregroundStyle(Theme.muted)
                    Text(origin).font(Theme.section(.title3)).foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TO").font(Theme.text(.caption, weight: .bold)).foregroundStyle(Theme.muted)
                    Text(destination).font(Theme.section(.title3)).foregroundStyle(Theme.ink).multilineTextAlignment(.trailing)
                }
            }
            RouteDash()
                .frame(maxWidth: .infinity)
            Text("Posted cities only. The road route and fee appear after you choose a place. Home Run does not track the car.")
                .font(Theme.text(.footnote))
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
                .font(Theme.text(.subheadline))
                .foregroundStyle(Theme.muted)
            Text(spotLine)
                .font(Theme.text(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
            if let name = Format.personalName(trip.driver?.displayName) {
                Text(name).font(Theme.text(.subheadline)).foregroundStyle(Theme.muted)
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

struct PageHeader: View {
    var title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.brand(.title))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(Theme.text(.subheadline))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }
}

struct ChoiceBar<Value: Hashable>: View {
    var options: [Value]
    var label: (Value) -> String
    @Binding var selection: Value
    @Namespace private var space
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    if reduceMotion {
                        selection = option
                    } else {
                        withAnimation(.spring(duration: 0.32, bounce: 0.16)) {
                            selection = option
                        }
                    }
                } label: {
                    Text(label(option))
                        .font(Theme.text(.subheadline, weight: .semibold))
                        .foregroundStyle(selection == option ? Color.white : Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.maroon)
                                    .matchedGeometryEffect(id: "choice", in: space)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
    }
}
