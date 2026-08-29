import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(Theme.cyan)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(title)
                .font(Theme.display(15, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct StatusPill: View {
    enum Style { case ok, warn, bad, neutral }
    let text: String
    var style: Style = .neutral
    var systemImage: String? = nil

    private var color: Color {
        switch style {
        case .ok: return Theme.green
        case .warn: return Theme.amber
        case .bad: return Theme.rose
        case .neutral: return Theme.cyan
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassChip()
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var icon: String? = nil
    var accent: Color = Theme.cyan
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            if let caption {
                Text(caption)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var valueColor: Color = Theme.ink
    var monospace: Bool = true

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(monospace ? Theme.mono(13) : .system(size: 13, weight: .semibold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 9)
    }
}

struct GlassButton: View {
    let title: String
    var icon: String? = nil
    var prominent: Bool = false
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(prominent ? Theme.bgTop : Theme.cyan)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(prominent ? Theme.bgTop : Theme.ink)
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: Theme.r1, style: .continuous)
                        .fill(Theme.signalGradient)
                } else {
                    RoundedRectangle(cornerRadius: Theme.r1, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.r1, style: .continuous)
                                .strokeBorder(Theme.glassStroke, lineWidth: 1)
                        )
                }
            }
        }
        .disabled(isLoading)
    }
}
