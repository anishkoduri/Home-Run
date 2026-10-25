import SwiftUI

@main
struct HomeRunApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.font, Theme.text())
                .tint(Theme.maroon)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showLaunch = true
    @State private var crossed = false
    @State private var handoff: CGFloat = 0
    @State private var revealed = false

    var body: some View {
        ZStack {
            destination
                .scaleEffect(1.08 - 0.08 * handoff)
                .offset(y: 72 * (1 - handoff))
            if showLaunch {
                LaunchSlide(crossed: crossed) { crossed = true }
                    .scaleEffect(1 + handoff * 1.65, anchor: UnitPoint(x: 0.32, y: 0.56))
                    .opacity(1 - max(0, (handoff - 0.42) / 0.58))
                    .allowsHitTesting(handoff == 0)
            }
        }
        .onChange(of: crossed) { _, done in
            guard done, !model.restoring else { return }
            reveal()
        }
        .onChange(of: model.restoring) { _, restoring in
            guard !restoring, crossed else { return }
            reveal()
        }
        .task { await model.restore() }
    }

    private func reveal() {
        guard !revealed else { return }
        revealed = true
        if reduceMotion {
            handoff = 1
            showLaunch = false
            return
        }
        withAnimation(.timingCurve(0.15, 0.7, 0.2, 1, duration: 0.62)) {
            handoff = 1
        }
        Task {
            try? await Task.sleep(for: .milliseconds(640))
            showLaunch = false
        }
    }

    @ViewBuilder
    private var destination: some View {
        Group {
            if model.restoring {
                Theme.artwork
            } else if model.user == nil {
                AuthView()
            } else if model.profile == nil {
                VStack(spacing: 16) {
                    ErrorBanner(message: model.restoreError ?? "Your profile couldn't be loaded.")
                    Button("Try again") { Task { await model.restore() } }
                    Button("Sign out") { Task { await model.signOut() } }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cream)
            } else {
                MainTabs()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if model.side == .driving, model.profile?.use != .order {
                DriveShell()
            } else {
                OrderShell()
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: model.side)
        .sensoryFeedback(.selection, trigger: model.side)
        .task {
            while !Task.isCancelled {
                await model.refreshBadges()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}

private struct OrderShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var tab = Tab.home
    @State private var orderOnly = false

    enum Tab: Hashable { case home, discover, orders, profile }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home: HomeView()
                case .discover: DiscoverView()
                case .orders: OrdersView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .center, spacing: 4) {
                tabButton("Home", "house", .home)
                tabButton("Discover", "magnifyingglass", .discover)
                tabButton("Orders", "bag", .orders, badge: model.ordersBadge)
                tabButton("Profile", "person", .profile)
                Button {
                    if model.profile?.use == .order { orderOnly = true }
                    else { model.side = .driving }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "car.fill")
                        if !typeSize.isAccessibilitySize {
                            Text("Bring food")
                                .font(Theme.text(.caption, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        if model.driveBadge > 0 {
                            Text("\(model.driveBadge)").font(.caption2.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.maroon)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(model.driveBadge > 0 ? "Bring food, \(model.driveBadge) waiting" : "Bring food")
                .accessibilityHint("Opens the driver side of Home Run")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Theme.surface)
            .overlay(alignment: .top) { Hairline() }
        }
        .background(Theme.cream)
        .tint(Theme.maroon)
        .alert("This account is for ordering", isPresented: $orderOnly) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose deliver or both when you create an account to bring food.")
        }
    }

    private func tabButton(_ title: String, _ symbol: String, _ value: Tab, badge: Int = 0) -> some View {
        Button {
            tab = value
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                if !typeSize.isAccessibilitySize {
                    Text(title)
                        .font(Theme.text(.caption, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if badge > 0 { Text("\(badge)").font(.caption2.weight(.bold)) }
            }
            .foregroundStyle(tab == value ? Theme.maroon : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge > 0 ? "\(title), \(badge)" : title)
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}

private struct DriveShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var section = DriveView.Section.requests

    var body: some View {
        VStack(spacing: 0) {
            DriveView(section: $section)
            HStack(spacing: 8) {
                ForEach(DriveView.Section.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.symbol)
                            if !typeSize.isAccessibilitySize {
                                Text(item.rawValue)
                                    .font(Theme.text(.caption, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .foregroundStyle(section == item ? .white : Theme.roadMuted)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                if model.profile?.use != .deliver {
                    Button {
                        model.side = .ordering
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "bag.fill")
                            if !typeSize.isAccessibilitySize {
                                Text("Order")
                                    .font(Theme.text(.caption, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .foregroundStyle(Theme.maroon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Theme.road)
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.16)).frame(height: 1) }
        }
        .background(Theme.road)
        .tint(.white)
        .environment(\.onTheRoad, true)
        .environment(\.colorScheme, .dark)
    }
}
