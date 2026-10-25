import SwiftUI

/// Full-screen open: the runner slides in from the right and crosses a fixed plate, then the home screen is revealed.
struct LaunchSlide: View {
    var crossed: Bool
    var onCrossed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            let plate = min(84, geo.size.width * 0.2)
            let runnerWidth = min(geo.size.width * 0.78, 340)
            let runnerHeight = runnerWidth * (614 / 742)
            let plateX = geo.size.width * 0.24
            let plateY = geo.size.height * 0.56
            let footY = runnerHeight * 0.78
            let endX = plateX - plate * 0.2
            let startX = geo.size.width - 28
            let x = startX + (endX - startX) * progress

            ZStack {
                Theme.artwork.overlay(PaperFiber())
                Canvas { context, _ in
                    let rect = CGRect(x: plateX - plate / 2, y: plateY - plate / 2, width: plate, height: plate)
                    context.fill(HomePlateShape().path(in: rect), with: .color(.white))
                }
                Image("SlideRunner")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: runnerWidth, height: runnerHeight)
                    .position(x: x + runnerWidth / 2, y: plateY - footY + runnerHeight / 2)
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
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                onCrossed()
            }
            return
        }
        withAnimation(.easeOut(duration: 1.05)) {
            progress = 1
        }
        Task {
            try? await Task.sleep(for: .milliseconds(1080))
            onCrossed()
        }
    }
}
