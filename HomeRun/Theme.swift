import SwiftUI

import UIKit

enum Theme {
    /// Sampled from the top edge of BrandMark.png. Do not substitute a generic red.
    static let maroon = Color(red: 80 / 255, green: 20 / 255, blue: 32 / 255)
    static let artwork = maroon
    static let maroonDark = Color(red: 44 / 255, green: 10 / 255, blue: 16 / 255)
    static let cream = Color(red: 246 / 255, green: 241 / 255, blue: 234 / 255)
    static let surface = Color.white
    static let tint = Color(red: 245 / 255, green: 242 / 255, blue: 241 / 255)
    static let gold = Color(red: 184 / 255, green: 146 / 255, blue: 90 / 255)
    static let coral = Color(red: 164 / 255, green: 78 / 255, blue: 58 / 255)
    static let ink = Color(red: 28 / 255, green: 18 / 255, blue: 20 / 255)
    static let muted = Color(red: 92 / 255, green: 78 / 255, blue: 76 / 255)
    static let line = Color(red: 230 / 255, green: 222 / 255, blue: 220 / 255)
    static let good = Color(red: 30 / 255, green: 107 / 255, blue: 82 / 255)
    static let bad = Color(red: 164 / 255, green: 42 / 255, blue: 42 / 255)
    static let road = Color(red: 32 / 255, green: 7 / 255, blue: 12 / 255)
    static let roadSurface = Color(red: 52 / 255, green: 14 / 255, blue: 20 / 255)
    static let roadMuted = Color(red: 232 / 255, green: 214 / 255, blue: 208 / 255)
    static let radiusCard: CGFloat = 20
    static let radiusControl: CGFloat = 14
    static let space: CGFloat = 20

    /// Collegiate display. Family name inside Graduate-Regular.ttf (SIL OFL).
    static func display(_ style: Font.TextStyle = .title2) -> Font {
        .custom("Graduate", size: displaySize(style), relativeTo: style)
    }

    /// Body face. Variable Source Sans 3 (SIL OFL).
    static func text(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .custom("Source Sans 3", size: textSize(style), relativeTo: style).weight(weight)
    }

    private static func displaySize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 40
        case .title: return 32
        case .title2: return 26
        case .title3: return 22
        case .headline: return 20
        default: return 18
        }
    }

    private static func textSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        default: return 17
        }
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

/// Low-contrast fiber behind maroon. Deterministic so it does not shimmer while scrolling.
struct PaperFiber: View {
    var tone: Color = .white

    var body: some View {
        Canvas { context, size in
            var index = 0
            let step: CGFloat = 8
            var y: CGFloat = 2
            while y < size.height {
                var x: CGFloat = CGFloat((index * 5) % 11)
                while x < size.width {
                    let seed = Int(x) * 13 + Int(y) * 7
                    let alpha = 0.035 + Double(seed % 5) * 0.008
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                    context.fill(Path(ellipseIn: rect), with: .color(tone.opacity(alpha)))
                    x += step
                }
                y += step
                index += 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct StitchMark: View {
    var tint: Color = .white.opacity(0.55)

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< 7, id: \.self) { _ in
                Capsule()
                    .fill(tint)
                    .frame(width: 9, height: 2)
            }
        }
        .accessibilityHidden(true)
    }
}

struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct OnTheRoadKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onTheRoad: Bool {
        get { self[OnTheRoadKey.self] }
        set { self[OnTheRoadKey.self] = newValue }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .overlay(InkCard().stroke(Theme.ink.opacity(0.22), lineWidth: 1.2))
            .shadow(color: Theme.ink.opacity(0.05), radius: 12, y: 6)
    }
}

struct PrimaryButton: View {
    var title: String
    var busy: Bool = false
    var color: Color = Theme.maroon
    var foreground: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy { ProgressView().tint(foreground) }
                Text(title).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 12)
            .font(Theme.text(.body, weight: .semibold))
            .foregroundStyle(foreground)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(color)
                    .overlay(alignment: .top) {
                        Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
                    }
                    .shadow(color: color.opacity(0.28), radius: 8, y: 3)
            }
        }
        .buttonStyle(PressStyle())
        .disabled(busy)
    }
}

struct ErrorBanner: View {
    var message: String
    var body: some View {
        Text(message)
            .font(Theme.text(.footnote))
            .foregroundStyle(Theme.bad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(red: 1, green: 245 / 255, blue: 243 / 255))
            .sketchPanel(fill: Color(red: 1, green: 245 / 255, blue: 243 / 255), ink: Theme.bad.opacity(0.35))
    }
}

struct StatusPill: View {
    var status: OrderStatus
    var body: some View {
        Text(status.label)
            .font(Theme.text(.caption, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch status.tone {
        case .pending: return Color(red: 138 / 255, green: 90 / 255, blue: 18 / 255)
        case .completed: return Theme.good
        case .closed: return Theme.muted
        case .active: return Theme.maroon
        }
    }

    private var background: Color {
        switch status.tone {
        case .pending: return Color(red: 251 / 255, green: 239 / 255, blue: 217 / 255)
        case .completed: return Color(red: 230 / 255, green: 241 / 255, blue: 236 / 255)
        case .closed: return Theme.tint
        case .active: return Theme.maroon.opacity(0.12)
        }
    }
}

struct Avatar: View {
    var name: String?
    var body: some View {
        Text(initials(name))
            .font(Theme.text(.subheadline, weight: .bold))
            .frame(width: 40, height: 40)
            .foregroundStyle(Theme.maroon)
            .background(Theme.tint)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

struct PlacePlate: View {
    var name: String

    var body: some View {
        Text(initials(name))
            .font(Theme.text(.headline, weight: .bold))
            .foregroundStyle(Theme.maroon)
            .frame(width: 56, height: 56)
            .background(Theme.tint)
            .clipShape(InkCard())
            .overlay(InkCard().stroke(Theme.maroon.opacity(0.45), lineWidth: 1.2))
            .accessibilityHidden(true)
    }
}

struct EmptyState: View {
    var title: String
    var message: String
    var ink: Color = Theme.maroon

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            GroceryBagSketch(ink: ink)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(Theme.display(.headline))
                Text(message).font(Theme.text(.subheadline)).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sketchPanel()
    }
}

/// Paper on the ordering side, printed maroon on the driver side.
/// New screens should call `homeRunPage()` instead of setting their own background.
struct HomeRunPage: ViewModifier {
    var road: Bool?
    @Environment(\.onTheRoad) private var onTheRoad

    private var useRoad: Bool { road ?? onTheRoad }

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                if useRoad {
                    Theme.road.overlay(PaperFiber())
                } else {
                    Theme.cream.overlay(PaperFiber(tone: Theme.maroon))
                }
            }
    }
}

struct SketchBackdrop: ViewModifier {
    var fill: Color = Theme.surface
    var ink: Color = Theme.ink.opacity(0.28)

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(InkCard())
            .overlay(InkCard().stroke(ink, lineWidth: 1.3))
    }
}

extension View {
    /// Shared surface for every screen. Pass `road: false` for a paper ticket inside the driver shell.
    func homeRunPage(road: Bool? = nil) -> some View {
        modifier(HomeRunPage(road: road))
    }

    func sketchPanel(fill: Color = Theme.surface, ink: Color = Theme.ink.opacity(0.28)) -> some View {
        modifier(SketchBackdrop(fill: fill, ink: ink))
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.homeRunPage(road: false)
    }
}
