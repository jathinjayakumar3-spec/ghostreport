import SwiftUI

/// Speedometer-style radial gauge for the speed test hero metric — the
/// "smart-home dial" look, rendered against a frosted glass disc.
struct RadialGauge: View {
    let value: Double          // current value, e.g. Mbps
    let maxValue: Double       // scale ceiling
    let unit: String
    let label: String
    var accent: Color = Theme.cyan

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 18)

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(
                    AngularGradient(colors: [accent.opacity(0.4), accent, Theme.violet], center: .center),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: accent.opacity(0.6), radius: 10)
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)

            VStack(spacing: 4) {
                Text(value > 0 ? String(format: value < 10 ? "%.2f" : "%.1f", value) : "—")
                    .font(Theme.display(40))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .textCase(.uppercase)
                    .tracking(1)
            }
        }
        .padding(22)
        .background(Circle().fill(.ultraThinMaterial))
        .overlay(Circle().strokeBorder(Theme.glassStroke, lineWidth: 1))
        .shadow(color: Theme.glassShadow, radius: 24, y: 12)
    }
}

/// Lightweight hand-drawn sparkline for realtime throughput/latency strips
/// where a full Swift Charts axis would be visual noise.
struct Sparkline: View {
    let samples: [Double]
    var color: Color = Theme.cyan
    var fill: Bool = true

    var body: some View {
        GeometryReader { geo in
            let pts = normalizedPoints(in: geo.size)
            ZStack {
                if fill, pts.count > 1 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        for pt in pts { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                }
                if pts.count > 1 {
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard samples.count > 1 else { return [] }
        let maxV = max(samples.max() ?? 1, 0.0001)
        let minV = min(samples.min() ?? 0, maxV - 0.0001)
        let range = maxV - minV
        let stepX = size.width / CGFloat(samples.count - 1)
        return samples.enumerated().map { i, v in
            let n = (v - minV) / range
            return CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat(n) * size.height)
        }
    }
}
