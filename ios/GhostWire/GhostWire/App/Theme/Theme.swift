import SwiftUI

/// Central design-token store for GhostWire's "glassy" dark network-ops aesthetic:
/// deep navy ground, frosted translucent cards, electric cyan + violet signal colors.
enum Theme {

    // MARK: Ground

    static let bgTop = Color(hex: 0x070B14)
    static let bgBottom = Color(hex: 0x0C1220)
    static let bgOrbCyan = Color(hex: 0x21E6C1)
    static let bgOrbViolet = Color(hex: 0x7C6CFF)

    static var backdrop: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }

    // MARK: Signal palette

    static let cyan = Color(hex: 0x2BE6D6)
    static let cyanLift = Color(hex: 0x6FF6E8)
    static let violet = Color(hex: 0x8A7CFF)
    static let violetLift = Color(hex: 0xB0A6FF)
    static let amber = Color(hex: 0xF5A623)
    static let rose = Color(hex: 0xFF5C7A)
    static let green = Color(hex: 0x39D98A)

    static var signalGradient: LinearGradient {
        LinearGradient(colors: [cyan, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Ink

    static let ink = Color(hex: 0xF3F8FA)
    static let ink2 = Color(hex: 0xB9C7D4)
    static let muted = Color(hex: 0x7C8EA0)
    static let faint = Color(hex: 0x4C5C6C)

    // MARK: Glass

    static let glassStroke = Color.white.opacity(0.14)
    static let glassStrokeHi = Color.white.opacity(0.30)
    static let glassShadow = Color.black.opacity(0.45)

    // MARK: Radii / spacing

    static let r1: CGFloat = 12
    static let r2: CGFloat = 20
    static let r3: CGFloat = 28
    static let spacing: CGFloat = 16

    // MARK: Fonts

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Status color for a qualitative rating used across ping/speed/signal metrics.
    static func quality(_ score: Double) -> Color {
        switch score {
        case 0.75...: return green
        case 0.45..<0.75: return amber
        default: return rose
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
