import SwiftUI

/// Frosted glass card surface: `.ultraThinMaterial` blur, faint hairline stroke,
/// soft outer glow — the recurring "glassy touch" surface used everywhere in GhostWire.
struct GlassSurface: ViewModifier {
    var corner: CGFloat = Theme.r2
    var strokeOpacity: Double = 1
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(tint.opacity(0.05))
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.glassStrokeHi.opacity(strokeOpacity), Theme.glassStroke.opacity(strokeOpacity)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: Theme.glassShadow, radius: 18, x: 0, y: 10)
    }
}

extension View {
    func glassCard(corner: CGFloat = Theme.r2, tint: Color = .white) -> some View {
        modifier(GlassSurface(corner: corner, tint: tint))
    }

    /// Thin glass chip used for pills / badges / tab bars.
    func glassChip(corner: CGFloat = 999) -> some View {
        modifier(GlassSurface(corner: corner, strokeOpacity: 0.7))
    }
}

/// Soft blurred gradient orbs that float behind content, matching the
/// smart-home-style glassy backdrop referenced for GhostWire.
struct AnimatedBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()

            Circle()
                .fill(Theme.bgOrbCyan.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: drift ? -110 : -70, y: drift ? -260 : -300)

            Circle()
                .fill(Theme.bgOrbViolet.opacity(0.30))
                .frame(width: 360, height: 360)
                .blur(radius: 130)
                .offset(x: drift ? 130 : 90, y: drift ? 220 : 260)

            Circle()
                .fill(Theme.amber.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 140)
                .offset(x: drift ? -60 : -20, y: drift ? 40 : 10)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}
