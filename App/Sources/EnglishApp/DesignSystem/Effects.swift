import SwiftUI

/// Motion rules shared by every effect. With Reduce Motion on, nothing
/// scales, springs or flies: state changes simply appear.
enum Motion {
    static func pressScale(isPressed: Bool, reduceMotion: Bool) -> CGFloat {
        isPressed && !reduceMotion ? 0.97 : 1
    }

    static func spring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)
    }
}

/// Springy press feedback for any tappable row or card.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(Motion.pressScale(isPressed: configuration.isPressed, reduceMotion: reduceMotion))
            .animation(Motion.spring(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

extension View {
    /// Liquid Glass on iOS 26, frosted material before it.
    @ViewBuilder
    func appGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Soft card shadow; none in dark mode, where depth comes from the surface color.
    func cardShadow() -> some View {
        modifier(CardShadow())
    }
}

private struct CardShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 12, x: 0, y: 4)
    }
}

/// A short burst of sparkles for finished sessions. Static under Reduce Motion.
struct CelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false
    private let count = 12

    var body: some View {
        ZStack {
            if reduceMotion {
                Image(systemName: "sparkles").font(.title).foregroundStyle(Theme.accent)
            } else {
                ForEach(0..<count, id: \.self) { index in
                    let angle = Double(index) / Double(count) * 2 * .pi
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                        .font(.system(size: index.isMultiple(of: 2) ? 14 : 6))
                        .foregroundStyle(index.isMultiple(of: 3) ? Theme.accent : Theme.primary)
                        .offset(x: fired ? cos(angle) * 90 : 0, y: fired ? sin(angle) * 90 : 0)
                        .opacity(fired ? 0 : 1)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.2)) { fired = true }
        }
    }
}
