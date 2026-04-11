import SwiftUI

// MARK: - Mascot State

enum MascotState: Equatable {
    case idle        // No session — cat lying down
    case ready       // Session active, idle — cat sitting
    case thinking    // AI thinking — hare ears twitch
    case running     // Running tool — hare running
    case approval    // Needs approval — cat waving
    case input       // Waiting for input — cat head tilt
    case compacting  // Compacting context — turtle walking
    case ended       // Session ended — gray cat
}

// MARK: - Pixel Mascot View

struct PixelMascotView: View {
    let state: MascotState
    @State private var frameIndex = 0
    @State private var timer: Timer?

    var body: some View {
        Canvas { context, size in
            let frames = MascotFrameProvider.frames(for: state)
            let safeIndex = frameIndex % max(frames.count, 1)
            let pixels = frames[safeIndex]
            let gridSize = CGFloat(pixels.count)
            let pixelW = size.width / gridSize
            let pixelH = size.height / gridSize

            for (row, cols) in pixels.enumerated() {
                for (col, color) in cols.enumerated() {
                    if let color = color {
                        let rect = CGRect(
                            x: CGFloat(col) * pixelW,
                            y: CGFloat(row) * pixelH,
                            width: pixelW + 0.5, // slight overlap to avoid gaps
                            height: pixelH + 0.5
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: 22, height: 22)
        .onChange(of: state) { _, newState in
            frameIndex = 0
            restartTimer(for: newState)
        }
        .onAppear {
            restartTimer(for: state)
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func restartTimer(for mascotState: MascotState) {
        timer?.invalidate()
        let frames = MascotFrameProvider.frames(for: mascotState)
        guard frames.count > 1 else {
            timer = nil
            return
        }
        let interval = MascotFrameProvider.frameInterval(for: mascotState)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            frameIndex = (frameIndex + 1) % frames.count
        }
    }
}
