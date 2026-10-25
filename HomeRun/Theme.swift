import SwiftUI

import UIKit

enum Theme {
    /// Sampled from the top edge of BrandMark.png. Do not substitute a generic red.
    static let maroon = Color(red: 80 / 255, green: 20 / 255, blue: 32 / 255)
    static let artwork = maroon
    static let maroonDark = Color(red: 44 / 255, green: 10 / 255, blue: 16 / 255)
    static let cream = Color(red: 246 / 255, green: 241 / 255, blue: 234 / 255)
    /// Top of the ordering wash, so a visible bar matches the page behind it.
    static let orderingBar = Color(red: 240 / 255, green: 198 / 255, blue: 164 / 255)
    /// Ordering stays on cream. Running uses this warmer sheet so the workspace is obvious.
    static let runnerPaper = Color(red: 243 / 255, green: 228 / 255, blue: 224 / 255)
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

    /// Screen titles. Fraunces, SIL OFL, scaled with Dynamic Type.
    static func brand(_ style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Fraunces", size: brandSize(style), relativeTo: style).weight(.medium)
    }

    static func display(_ style: Font.TextStyle = .title2) -> Font {
        brand(style)
    }

    /// Section headings. Same serif, smaller, so they belong to the titles without becoming body text.
    static func section(_ style: Font.TextStyle = .title3) -> Font {
        .custom("Fraunces", size: sectionSize(style), relativeTo: style).weight(.medium)
    }

    /// Money. IBM Plex Mono, SIL OFL, so figures stay clear.
    static func price(_ style: Font.TextStyle = .title3) -> Font {
        mono(style, weight: .semibold)
    }

    /// Reading text and controls. Instrument Sans, SIL OFL. Captions and footnotes use mono.
    static func text(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        switch style {
        case .caption, .caption2, .footnote:
            return mono(style, weight: weight == .regular ? .medium : weight)
        default:
            return .custom("Instrument Sans", size: textSize(style), relativeTo: style).weight(weight)
        }
    }

    /// Static-enough face for UIKit fields. The variable SwiftUI font was swallowing taps.
    static func fieldFont(size: CGFloat = 17) -> UIFont {
        UIFont(name: "InstrumentSans-Regular", size: size)
            ?? UIFont(name: "Instrument Sans", size: size)
            ?? .systemFont(ofSize: size)
    }

    /// Labels, metadata, and small print. IBM Plex Mono, SIL OFL.
    static func mono(_ style: Font.TextStyle = .caption, weight: Font.Weight = .medium) -> Font {
        .custom("IBM Plex Mono", size: monoSize(style), relativeTo: style).weight(weight)
    }

    private static func brandSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 36
        case .title: return 30
        case .title2: return 26
        case .title3: return 22
        case .headline: return 20
        default: return 18
        }
    }

    private static func sectionSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 28
        case .title: return 24
        case .title2: return 22
        case .title3: return 20
        case .headline: return 18
        default: return 17
        }
    }

    /// Fraunces for screen titles in the navigation bar, matching `brand()`.
    static func screenFont(size: CGFloat) -> UIFont {
        UIFont(name: "Fraunces", size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }

    /// Light display serif for the name. Newsreader, SIL OFL, in the role of Claude’s headline face.
    /// Anthropic Serif is proprietary and is not embedded.
    static func wordmarkFont(size: CGFloat, bold: Bool = false) -> UIFont {
        let base = UIFont(name: "Newsreader", size: size)
            ?? UIFont(name: "NewsreaderRoman-Light", size: size)
            ?? .systemFont(ofSize: size, weight: .light)
        let display = size >= 36
        let variations: [NSNumber: NSNumber] = [
            2003265652: NSNumber(value: bold ? 620 : (display ? 300 : 360)),
            1869640570: NSNumber(value: Double(display ? 72 : max(6, min(72, size))))
        ]
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: "NSCTFontVariationAttribute"): variations
        ])
        return UIFont(descriptor: descriptor, size: size)
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

    private static func monoSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .title, .title2, .title3: return 20
        case .headline, .body: return 16
        case .callout: return 15
        case .subheadline: return 14
        case .footnote: return 12
        case .caption: return 12
        case .caption2: return 11
        default: return 13
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
    var tone: Color = Theme.maroon
    /// Content pages use a light tooth. Brand moments can pass `quiet: false`.
    var quiet = false

    var body: some View {
        Canvas { context, size in
            let area = size.width * size.height
            let count = quiet ? min(140, max(36, Int(area / 6400))) : min(280, max(60, Int(area / 2200)))
            for index in 0 ..< count {
                var state = UInt32(index) &* 1_103_515_245 &+ 12_345
                func unit() -> CGFloat {
                    state = state &* 1_664_525 &+ 1_013_904_223
                    return CGFloat(state % 10_000) / 10_000
                }
                let x = unit() * size.width
                let y = unit() * size.height
                let length: CGFloat = quiet ? 4 + unit() * 9 : (index % 11 == 0 ? 12 + unit() * 10 : 2.5 + unit() * 5)
                let angle = unit() * .pi
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                let alpha = quiet ? 0.05 + Double(unit()) * 0.06 : 0.05 + Double(unit()) * 0.06
                context.stroke(path, with: .color(tone.opacity(alpha)), lineWidth: quiet ? 0.45 : 0.7)
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
            .offset(
                x: !reduceMotion && configuration.isPressed ? 2 : 0,
                y: !reduceMotion && configuration.isPressed ? 3 : 0
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
            .sketchPanel()
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
                Text(title)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 12)
            .font(Theme.text(.body, weight: .bold))
            .foregroundStyle(foreground)
        }
        .buttonStyle(StampButtonStyle(color: color))
        .disabled(busy)
    }
}

/// Press slides the ink onto its offset shadow. The shadow stays put.
struct StampButtonStyle: ButtonStyle {
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        configuration.label
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color))
            .shadow(color: color.opacity(pressed ? 0.05 : 0.22), radius: pressed ? 4 : 10, y: pressed ? 2 : 6)
            .scaleEffect(pressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
    var title: String? = nil

    var body: some View {
        Text(title ?? status.label)
            .font(Theme.text(.caption, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(foreground.opacity(0.45), lineWidth: 1))
            .accessibilityLabel(title ?? status.label)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.gold.opacity(0.85), lineWidth: 1.25))
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
                Text(title).font(Theme.section(.headline))
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
                Group {
                    if useRoad {
                        Theme.runnerPaper.overlay(PaperFiber(tone: Theme.maroon, quiet: true))
                    } else {
                        OrderingCanvas()
                    }
                }
                .ignoresSafeArea()
            }
    }
}

private struct GlassShape: View {
    var fill: Color
    var ink: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(fill.opacity(0.42)))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.9), ink.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

/// Warm field behind every ordering screen. Running keeps `runnerPaper`.
struct OrderingCanvas: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 228 / 255, green: 176 / 255, blue: 118 / 255),
                Color(red: 240 / 255, green: 198 / 255, blue: 164 / 255),
                Color(red: 244 / 255, green: 214 / 255, blue: 190 / 255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [Theme.coral.opacity(0.34), Color.clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 520
            )
        )
        .overlay(PaperFiber(tone: Theme.maroon, quiet: true))
    }
}

struct SketchBackdrop: ViewModifier {
    var fill: Color = .white
    var ink: Color = Color.white.opacity(0.85)
    @Environment(\.onTheRoad) private var onTheRoad

    func body(content: Content) -> some View {
        content
            .background { GlassShape(fill: fill, ink: onTheRoad ? ink : Theme.gold) }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                if !onTheRoad {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Theme.gold, Theme.coral.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.25
                        )
                }
            }
            .shadow(color: (onTheRoad ? Theme.ink : Theme.maroon).opacity(0.14), radius: 18, y: 10)
    }
}

struct TicketBackdrop: ViewModifier {
    var open: Bool = false
    @Environment(\.onTheRoad) private var onTheRoad

    func body(content: Content) -> some View {
        content
            .background {
                GlassShape(fill: .white, ink: onTheRoad ? Color.white.opacity(open ? 0.95 : 0.8) : Theme.gold)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(
                        onTheRoad
                            ? AnyShapeStyle(Theme.maroon.opacity(open ? 1 : 0.7))
                            : AnyShapeStyle(LinearGradient(colors: [Theme.gold, Theme.coral], startPoint: .top, endPoint: .bottom))
                    )
                    .frame(width: 3)
            }
            .shadow(color: Theme.maroon.opacity(open ? 0.16 : 0.06), radius: open ? 16 : 12, y: 8)
    }
}

extension View {
    /// Shared surface for every screen. Pass `road: false` for a paper ticket inside the driver shell.
    func homeRunPage(road: Bool? = nil) -> some View {
        modifier(HomeRunPage(road: road))
    }

    func sketchPanel(fill: Color = Theme.surface, ink: Color = Theme.line) -> some View {
        modifier(SketchBackdrop(fill: fill, ink: ink))
    }

    func ticketPanel(open: Bool = false) -> some View {
        modifier(TicketBackdrop(open: open))
    }

    func mapFrame() -> some View {
        modifier(MapFrame())
    }
}

private struct MapFrame: ViewModifier {
    @Environment(\.onTheRoad) private var onTheRoad

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(onTheRoad ? Color.white.opacity(0.72) : Theme.gold.opacity(0.9), lineWidth: 1.25)
            )
            .shadow(color: Theme.maroon.opacity(onTheRoad ? 0.18 : 0.12), radius: 16, y: 8)
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.homeRunPage(road: false)
    }
}
