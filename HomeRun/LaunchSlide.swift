import SwiftUI

/// Full-screen open: the runner slides in from the right and crosses a fixed plate, then the home screen is revealed.
struct LaunchSlide: View {
    var crossed: Bool
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
                max(margin, geo.size.height * 0.56 - runnerHeight * 0.78),
                geo.size.height - runnerHeight - margin
            )
            let centerY = runnerTop + runnerHeight / 2
            let endX = max(margin, (geo.size.width - runnerWidth) / 2)
            let startX = geo.size.width + margin
            let x = startX + (endX - startX) * progress
            let plateX = endX + runnerWidth * 0.16
            let plateY = runnerTop + runnerHeight * 0.80

            ZStack {
                LaunchBackdrop()
                Rectangle()
                    .fill(Theme.artwork)
                    .frame(width: runnerWidth + 4, height: runnerHeight + 4)
                    .position(x: x + runnerWidth / 2, y: centerY)
                Canvas { context, _ in
                    let rect = CGRect(x: plateX - plate / 2, y: plateY - plate / 2, width: plate, height: plate)
                    context.fill(HomePlateShape().path(in: rect), with: .color(.white))
                }
                Image("SlideRunner")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: runnerWidth, height: runnerHeight)
                    .position(x: x + runnerWidth / 2, y: centerY)
                    .accessibilityHidden(true)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Home Run")
        .onAppear(perform: play)
        .sensoryFeedback(.impact(weight: .medium), trigger: crossed)
    }

    private func play() {
        guard !started else { return }
        started = true
        if reduceMotion {
            progress = 1
            finish()
            return
        }
        withAnimation(.timingCurve(0.16, 0.8, 0.2, 1, duration: 0.58)) {
            progress = 1
        } completion: {
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onCrossed()
    }
}

/// Solid maroon and fiber. Kept separate so the fiber does not redraw while the runner moves.
private struct LaunchBackdrop: View {
    var body: some View {
        Theme.artwork.overlay(PaperFiber())
    }
}
