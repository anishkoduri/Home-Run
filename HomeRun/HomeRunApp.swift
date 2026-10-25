import SwiftUI

@main
struct HomeRunApp: App {
    @State private var model = AppModel()

    init() {
        let body = UIFont(name: "Source Sans 3", size: 17) ?? .systemFont(ofSize: 17)
        let caption = UIFont(name: "IBMPlexMono-Medium", size: 12) ?? UIFont(name: "IBM Plex Mono", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .medium)
        let cream = UIColor(red: 246 / 255, green: 241 / 255, blue: 234 / 255, alpha: 1)
        let ink = UIColor(red: 28 / 255, green: 18 / 255, blue: 20 / 255, alpha: 1)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = cream
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: Theme.wordmarkFont(size: 18), .foregroundColor: ink]
        appearance.largeTitleTextAttributes = [.font: Theme.wordmarkFont(size: 30), .foregroundColor: ink]
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
    /// Stays @State so tab changes, role switches, and foregrounding do not replay the open.
    @State private var showLaunch = true
    @State private var crossed = false
    @State private var handoff: CGFloat = 0
    @State private var revealed = false
    @State private var loadingReady = false
    @State private var loadCapHit = false
    @State private var mountHome = false
    @State private var pageWidth: CGFloat = 0
    @State private var runnerSettledAt: Date?

    private var cover: Bool { showLaunch && !reduceMotion }

    var body: some View {
        ZStack {
            Theme.cream
            if !cover || mountHome {
                destination
                    .opacity(cover ? 0 : 1)
                    .accessibilityHidden(cover)
            }
            if cover {
                LaunchSlide { noteRunnerSettled() }
                    .compositingGroup()
                    .scaleEffect(1 + (0.55 * handoff), anchor: .center)
                    .opacity(1 - handoff)
                    .allowsHitTesting(handoff == 0)
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: LaunchWidthKey.self, value: geo.size.width)
            }
        }
        .onPreferenceChange(LaunchWidthKey.self) { width in
            if width > 0, width != pageWidth { pageWidth = width }
        }
        .onAppear {
            if reduceMotion { finishImmediately() }
        }
        .onChange(of: reduceMotion) { _, reduce in
            if reduce { finishImmediately() }
        }
        .task {
            // Next run-loop turn: the launch slide can commit before session restore.
            // Map startup stays off this path. It is synchronous on the main thread.
            await Task.yield()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.main.async { continuation.resume() }
            }
            guard !loadingReady else { return }
            await model.restore()
            loadingReady = true
            revealIfReady()
        }
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled, showLaunch, !revealed else { return }
            loadCapHit = true
            revealIfReady()
        }
    }

    private func noteRunnerSettled() {
        guard !crossed else { return }
        crossed = true
        runnerSettledAt = Date()
        GoogleMapsStartup.start()
        revealIfReady()
    }

    private func revealIfReady() {
        guard !revealed else { return }
        if reduceMotion {
            finishImmediately()
            return
        }
        guard crossed || loadCapHit else { return }
        guard loadingReady || loadCapHit else { return }
        revealed = true
        if !crossed {
            GoogleMapsStartup.start()
        }
        mountHome = true
        Task { @MainActor in
            let elapsed = Date().timeIntervalSince(runnerSettledAt ?? Date())
            let linger = max(0, 0.1 - elapsed)
            if linger > 0 { try? await Task.sleep(for: .seconds(linger)) }
            guard showLaunch else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                handoff = 1
            } completion: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { showLaunch = false }
            }
        }
    }

    private func finishImmediately() {
        guard !revealed else { return }
        revealed = true
        crossed = true
        handoff = 1
        mountHome = true
        showLaunch = false
        Task { @MainActor in
            await Task.yield()
            GoogleMapsStartup.start()
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

private struct LaunchWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if model.side == .driving {
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
    @State private var roots: [Tab: Int] = [:]
    @Namespace private var tabSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Tab: Hashable { case home, discover, orders, profile }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home: HomeView().id(roots[.home] ?? 0)
                case .discover: DiscoverView().id(roots[.discover] ?? 0)
                case .orders: OrdersView().id(roots[.orders] ?? 0)
                case .profile: ProfileView().id(roots[.profile] ?? 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            HStack(alignment: .center, spacing: 4) {
                tabButton("Home", "house", .home)
                tabButton("Discover", "magnifyingglass", .discover)
                tabButton("Orders", "bag", .orders, badge: model.ordersBadge)
                tabButton("Profile", "person", .profile)
                Button {
                    model.cityPickerOpen = false
                    model.side = .driving
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "car.fill")
                        if !typeSize.isAccessibilitySize {
                            Text("Running")
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
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.maroon))
                    .shadow(color: Theme.maroon.opacity(0.28), radius: 8, y: 4)
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("bring-food")
                .accessibilityLabel(model.driveBadge > 0 ? "Running, \(model.driveBadge) waiting" : "Running")
                .accessibilityHint("Switches to the running workspace")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.7)).frame(height: 1) }
            .zIndex(1)
        }
        .homeRunPage(road: false)
        .tint(Theme.maroon)
        .sheet(isPresented: Bindable(model).cityPickerOpen) {
            PickupCitySheet { name in
                model.confirmPickupCity(name)
            }
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
            if tab == value {
                roots[value, default: 0] += 1
                model.cityPickerOpen = false
            } else {
                tab = value
            }
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
                    InkCard()
                        .fill(Theme.maroon.opacity(0.12))
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            HStack(spacing: 8) {
                ForEach(DriveView.Section.allCases) { item in
                    Button {
                        if section == item { model.driveRootTick += 1 }
                        else { section = item }
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
                        .foregroundStyle(section == item ? Theme.maroon : Color.white.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 6)
                        .background {
                            if section == item {
                                InkCard()
                                    .fill(Color.white)
                                    .matchedGeometryEffect(id: "drive-tab", in: tabSpace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.16), value: section)
                }
                Button {
                    model.cityPickerOpen = false
                    model.side = .ordering
                } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "bag.fill")
                            if !typeSize.isAccessibilitySize {
                                Text("Ordering")
                                    .font(Theme.text(.caption, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .foregroundStyle(Theme.maroon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.7), lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("get-food")
                    .accessibilityLabel("Ordering")
                    .accessibilityHint("Switches to the ordering workspace")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background {
                Theme.maroon.ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1) }
            .zIndex(1)
        }
        .homeRunPage(road: false)
        .tint(Theme.maroon)
        .environment(\.onTheRoad, true)
    }
}
