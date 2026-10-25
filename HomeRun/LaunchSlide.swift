import SwiftUI

/// Runner slides in from the right across a fixed plate.
/// `onCrossed` means the runner has settled. The parent keeps this cover up while the app loads.
struct LaunchSlide: View {
    var onCrossed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var started = false
    @State private var didFinish = false

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = 18
            let plate = min(72, geo.size.width * 0.16)
            let runnerWidth = min(geo.size.width - margin * 2, min(geo.size.width * 0.72, 300))
            let runnerHeight = runnerWidth * (614.0 / 742.0)
            let runnerTop = min(
                max(margin, geo.size.height * 0.42 - runnerHeight * 0.2),
                geo.size.height - runnerHeight - margin
            )
            let centerY = runnerTop + runnerHeight / 2
            let endX = max(margin, (geo.size.width - runnerWidth) / 2)
            let startX = geo.size.width + margin
            let x = startX + (endX - startX) * progress
            let plateX = endX + runnerWidth * 0.16
            let plateY = runnerTop + runnerHeight * 0.80

            ZStack {
                Theme.artwork
                Canvas { context, _ in
                    let rect = CGRect(x: plateX - plate / 2, y: plateY - plate / 2, width: plate, height: plate)
                    context.fill(HomePlateShape().path(in: rect), with: .color(.white))
                }
                .allowsHitTesting(false)
                Image("SlideRunner")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: runnerWidth, height: runnerHeight)
                    .position(x: x + runnerWidth / 2, y: centerY)
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        .compositingGroup()
        .onAppear(perform: play)
    }

    private func play() {
        guard !started else { return }
        started = true
        if reduceMotion {
            finish()
            return
        }
        withAnimation(.timingCurve(0.16, 0.8, 0.2, 1, duration: 0.68)) {
            progress = 1
        } completion: {
            finish()
        }
        // Completion can be skipped if the view updates mid-flight. This only marks the
        // runner settled; it does not dismiss the cover.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onCrossed()
    }
}
