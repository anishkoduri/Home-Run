import SwiftUI

@main
struct HomeRunApp: App {
    @State private var model = AppModel()

    init() {
        GoogleMapsStartup.start()
        let display = UIFont(name: "Fraunces", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        let body = UIFont(name: "Source Sans 3", size: 17) ?? .systemFont(ofSize: 17)
        let caption = UIFont(name: "Source Sans 3", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold)
        let cream = UIColor(red: 246 / 255, green: 241 / 255, blue: 234 / 255, alpha: 1)
        let ink = UIColor(red: 28 / 255, green: 18 / 255, blue: 20 / 255, alpha: 1)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = cream
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: display, .foregroundColor: ink]
        appearance.largeTitleTextAttributes = [.font: UIFont(name: "Fraunces", size: 30) ?? display, .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: body], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: body], for: .highlighted)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: caption], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: caption], for: .selected)
        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
    }

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
                .offset(y: reduceMotion ? 0 : 12 * (1 - handoff))
            if showLaunch, !reduceMotion {
                LaunchSlide(crossed: crossed) { crossed = true }
                    .opacity(1 - handoff)
                    .allowsHitTesting(handoff == 0)
            }
        }
        .onAppear {
            if reduceMotion {
                handoff = 1
                showLaunch = false
                revealed = true
            }
        }
        .onChange(of: reduceMotion) { _, reduce in
            if reduce {
                handoff = 1
                showLaunch = false
                revealed = true
            }
        }
        .onChange(of: crossed) { _, done in
            guard done else { return }
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
        withAnimation(.easeOut(duration: 0.22)) {
            handoff = 1
        } completion: {
            showLaunch = false
        }
    }

    @ViewBuilder
    private var destination: some View {
        Group {
            if model.restoring {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .homeRunPage(road: false)
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
                .homeRunPage(road: false)
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
    @State private var termsTick = 0

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
        .overlay {
            if let user = model.user, !DemoTerms.accepted(by: user.id) {
                TermsGate(userId: user.id) { termsTick += 1 }
            }
        }
        .id(termsTick)
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
    @Namespace private var tabSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                            Text("\(model.driveBadge)").font(Theme.text(.caption2, weight: .bold))
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
            .background {
                Theme.surface.overlay(PaperFiber(tone: Theme.maroon))
                    .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) { Hairline() }
        }
        .homeRunPage(road: false)
        .tint(Theme.maroon)
        .alert("This account is for ordering", isPresented: $orderOnly) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose deliver or both when you create an account to bring food.")
        }
        .onChange(of: model.requestedCustomerTab) { _, value in
            if value == "discover" {
                tab = .discover
                model.requestedCustomerTab = nil
            }
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
                if badge > 0 { Text("\(badge)").font(Theme.text(.caption2, weight: .bold)) }
            }
            .foregroundStyle(tab == value ? Theme.maroon : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .background {
                if tab == value {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.maroon.opacity(0.1))
                        .matchedGeometryEffect(id: "order-tab", in: tabSpace)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.16), value: tab)
        .accessibilityLabel(badge > 0 ? "\(title), \(badge)" : title)
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}

private struct DriveShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var section = DriveView.Section.requests
    @Namespace private var tabSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .foregroundStyle(section == item ? Color.white : Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 6)
                        .background {
                            if section == item {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.maroon)
                                    .matchedGeometryEffect(id: "drive-tab", in: tabSpace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.16), value: section)
                }
                if model.profile?.use != .deliver {
                    Button {
                        model.side = .ordering
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "bag.fill")
                            if !typeSize.isAccessibilitySize {
                                Text("Get food")
                                    .font(Theme.text(.caption, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.maroon)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Get food")
                    .accessibilityHint("Opens the ordering side of Home Run")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background {
                Theme.surface.overlay(PaperFiber(tone: Theme.maroon))
                    .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) { Hairline() }
        }
        .homeRunPage(road: false)
        .tint(Theme.maroon)
        .environment(\.onTheRoad, true)
    }
}
