import SwiftUI

/// Custom trapezoid shape that's wider at the bottom than the top
/// Creates a subtle "growing out of menu bar" effect (for notch screens)
struct TrapezoidShape: Shape {
    var topWidthRatio: CGFloat = 0.95

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset = rect.width * (1 - topWidthRatio) / 2
        let r = VibeCodeConstants.panelCornerRadius

        path.move(to: CGPoint(x: topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        path.addQuadCurve(to: CGPoint(x: rect.width - r, y: rect.height), control: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - r), control: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: topInset, y: 0))
        path.closeSubpath()
        return path
    }
}

/// Menu bar pill shape: top flush with menu bar, bottom two corners rounded
struct MenuBarPillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 14

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        path.addArc(center: CGPoint(x: rect.width - r, y: rect.height - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addArc(center: CGPoint(x: r, y: rect.height - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// Helper to erase shape type
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

struct NotchContentView: View {
    let sessionManager: SessionManager
    let isExpanded: Bool
    let hasNotch: Bool
    let onToggle: () -> Void
    let onApprove: (String, String) -> Void
    let onQuestionSubmit: (String, [String: AnyCodableValue]) -> Void
    let onJumpToSession: (ClaudeSession) -> Void
    let onReplyToSession: (ClaudeSession, String) -> Void

    private var collapsedShape: AnyShape {
        hasNotch ? AnyShape(TrapezoidShape()) : AnyShape(MenuBarPillShape())
    }

    var body: some View {
        ZStack {
            if isExpanded {
                MenuBarPillShape()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        MenuBarPillShape()
                            .fill(Color.black.opacity(0.6))
                    )

                ExpandedView(
                    sessionManager: sessionManager,
                    hasNotch: hasNotch,
                    onApprove: onApprove,
                    onQuestionSubmit: onQuestionSubmit,
                    onJumpToSession: onJumpToSession,
                    onReplyToSession: onReplyToSession
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                collapsedShape
                    .fill(Color.black)

                CollapsedView(sessionManager: sessionManager)
                    .frame(height: VibeCodeConstants.collapsedHeight)
                    .transition(.opacity)
            }
        }
        .clipShape(AnyShape(MenuBarPillShape()))
        .ignoresSafeArea(.all)
        .onTapGesture { onToggle() }
    }
}
