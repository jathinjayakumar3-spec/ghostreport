import Foundation

enum Formatters {
    static func kbps(_ value: Double) -> String {
        if value >= 1000 { return String(format: "%.2f Mbps", value / 1000) }
        return String(format: "%.0f Kbps", value)
    }

    static func mbps(_ value: Double) -> String {
        if value <= 0 { return "—" }
        if value < 10 { return String(format: "%.2f Mbps", value) }
        return String(format: "%.1f Mbps", value)
    }

    static func ms(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f ms", value)
    }

    static func pct(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func timestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
