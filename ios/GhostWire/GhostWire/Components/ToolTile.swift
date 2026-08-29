import SwiftUI

/// Glass tile that navigates to one diagnostic tool — used on both the
/// Dashboard's quick-launch row and the full Tools tab.
struct ToolTile<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink { destination() } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                }
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.system(size: 10.5)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}
