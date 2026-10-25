import SwiftUI

enum Theme {
    static let maroon = Color(red: 80 / 255, green: 0, blue: 0)
    static let maroonDark = Color(red: 58 / 255, green: 0, blue: 0)
    static let cream = Color(red: 1, green: 245 / 255, blue: 233 / 255)
    static let surface = Color(red: 1, green: 253 / 255, blue: 249 / 255)
    static let tint = Color(red: 248 / 255, green: 238 / 255, blue: 228 / 255)
    static let gold = Color(red: 244 / 255, green: 184 / 255, blue: 96 / 255)
    static let coral = Color(red: 232 / 255, green: 138 / 255, blue: 112 / 255)
    static let ink = Color(red: 38 / 255, green: 32 / 255, blue: 42 / 255)
    static let muted = Color(red: 108 / 255, green: 98 / 255, blue: 104 / 255)
    static let line = Color(red: 234 / 255, green: 220 / 255, blue: 207 / 255)
    static let good = Color(red: 47 / 255, green: 111 / 255, blue: 90 / 255)
    static let bad = Color(red: 164 / 255, green: 63 / 255, blue: 63 / 255)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(foreground)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
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
        case .active: return Theme.gold.opacity(0.45)
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
            .background(Theme.gold)
            .clipShape(Circle())
    }
}
