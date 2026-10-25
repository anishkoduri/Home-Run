import SwiftUI

/// Brief branded open. The mark is on screen immediately. Nothing here waits on the network.
struct LaunchSlide: View {
    var onCrossed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false

    var body: some View {
        ZStack {
            Theme.artwork
            Image("BrandMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 168, height: 168)
                .accessibilityLabel("Home Run")
        }
        .ignoresSafeArea()
        .onAppear(perform: play)
    }

    private func play() {
        guard !started else { return }
        started = true
        if reduceMotion {
            onCrossed()
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            onCrossed()
        }
    }
}
