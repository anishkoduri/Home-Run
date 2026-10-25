import SwiftUI

@main
struct HowdyHaulApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.maroon)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.restoring {
                ProgressView("Loading Howdy Haul")
            } else if model.user == nil {
                AuthView()
            } else if model.profile == nil {
                VStack(spacing: 16) {
                    ErrorBanner(message: model.restoreError ?? "Your profile couldn't be loaded.")
                    Button("Try again") { Task { await model.restore() } }
                    Button("Sign out") { Task { await model.signOut() } }
                }
                .padding(24)
            } else {
                MainTabs()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream)
        .task { await model.restore() }
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
            OrdersView()
                .tabItem { Label("Orders", systemImage: "bag") }
                .badge(model.ordersBadge)
            DriveView()
                .tabItem { Label("Bring Food", systemImage: "car") }
                .badge(model.driveBadge)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .task {
            while !Task.isCancelled {
                await model.refreshBadges()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}
