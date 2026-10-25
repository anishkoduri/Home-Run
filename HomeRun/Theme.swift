import SwiftUI

import UIKit

enum Theme {
    static let maroon = Color(red: 80 / 255, green: 0, blue: 0)
    /// Matches the brand artwork background so the launch slide has no visible box.
    static let artwork = Color(red: 80 / 255, green: 20 / 255, blue: 32 / 255)
    static let maroonDark = Color(red: 48 / 255, green: 0, blue: 0)
    static let cream = Color(red: 247 / 255, green: 244 / 255, blue: 242 / 255)
    static let surface = Color.white
    static let tint = Color(red: 245 / 255, green: 242 / 255, blue: 241 / 255)
    static let gold = Color(red: 184 / 255, green: 146 / 255, blue: 90 / 255)
    static let coral = Color(red: 164 / 255, green: 78 / 255, blue: 58 / 255)
    static let ink = Color(red: 28 / 255, green: 18 / 255, blue: 20 / 255)
    static let muted = Color(red: 92 / 255, green: 78 / 255, blue: 76 / 255)
    static let line = Color(red: 230 / 255, green: 222 / 255, blue: 220 / 255)
    static let good = Color(red: 30 / 255, green: 107 / 255, blue: 82 / 255)
    static let bad = Color(red: 164 / 255, green: 42 / 255, blue: 42 / 255)
    static let road = Color(red: 42 / 255, green: 8 / 255, blue: 12 / 255)
    static let roadSurface = Color(red: 62 / 255, green: 16 / 255, blue: 22 / 255)
    static let roadMuted = Color(red: 232 / 255, green: 214 / 255, blue: 208 / 255)
    static let radiusCard: CGFloat = 20
    static let radiusControl: CGFloat = 14
    static let space: CGFloat = 20

    static func display(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.bold)
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
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line))
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
            .foregroundStyle(foreground)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .disabled(busy)
    }
}

struct ErrorBanner: View {
    var message: String
    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Theme.bad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(red: 1, green: 245 / 255, blue: 243 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct StatusPill: View {
    var status: OrderStatus
    var body: some View {
        Text(status.label)
            .font(.caption.weight(.bold))
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
            .font(.subheadline.weight(.bold))
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
            .font(.headline.weight(.bold))
            .foregroundStyle(Theme.maroon)
            .frame(width: 56, height: 56)
            .background(Theme.tint)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct EmptyState: View {
    var title: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.tint)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.cream)
    }
}
