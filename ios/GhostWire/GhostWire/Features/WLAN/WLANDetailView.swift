import SwiftUI

/// Full detail screen for the active Wi-Fi/interface connection. Shows every
/// field iOS actually exposes publicly, and is explicit — rather than
/// silent or fabricated — about the handful of radio-level fields
/// (RSSI/channel/band/PHY standard/link rate) that no App Store-safe API on
/// iOS can read.
struct WLANDetailView: View {
    @ObservedObject var vm: DashboardViewModel

    private var iface: NetworkInterfaceInfo? { vm.snapshot.primary }

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    identityCard
                    ipConfigCard
                    dnsCard
                    unavailableCard
                }
                .padding(18)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Wi-Fi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.refreshNow() }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle().fill(Theme.signalGradient.opacity(0.22)).frame(width: 50, height: 50)
                    Image(systemName: "wifi").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.cyan)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.snapshot.wifi.ssid ?? "Not connected")
                        .font(Theme.display(18))
                        .foregroundStyle(Theme.ink)
                    if let bssid = vm.snapshot.wifi.bssid {
                        Text(bssid).font(Theme.mono(11.5)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
            }
            if let secure = vm.snapshot.wifi.isSecure {
                StatusPill(text: secure ? "Secured network" : "Open network", style: secure ? .ok : .bad)
            }
        }
        .padding(16)
        .glassCard(corner: Theme.r3)
    }

    private var ipConfigCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "IP configuration", icon: "network")
            VStack(spacing: 0) {
                KeyValueRow(key: "Interface", value: iface?.name ?? "—")
                Divider().overlay(Theme.glassStroke)
                KeyValueRow(key: "IPv4 address", value: iface?.ipv4 ?? "—")
                Divider().overlay(Theme.glassStroke)
                KeyValueRow(key: "Subnet mask", value: iface?.netmask ?? "—")
                Divider().overlay(Theme.glassStroke)
                KeyValueRow(key: "IPv6 address", value: iface?.ipv6 ?? "—")
                Divider().overlay(Theme.glassStroke)
                KeyValueRow(key: "Gateway / router", value: vm.snapshot.gateway.routerIPv4 ?? "—")
            }
            .padding(.horizontal, 14)
            .glassCard()
        }
    }

    private var dnsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "DNS servers", icon: "server.rack")
            VStack(spacing: 0) {
                if vm.snapshot.gateway.dnsServers.isEmpty {
                    KeyValueRow(key: "Servers", value: "—")
                } else {
                    ForEach(Array(vm.snapshot.gateway.dnsServers.enumerated()), id: \.offset) { i, server in
                        if i > 0 { Divider().overlay(Theme.glassStroke) }
                        KeyValueRow(key: "DNS \(i + 1)", value: server)
                    }
                }
            }
            .padding(.horizontal, 14)
            .glassCard()
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Radio details", icon: "antenna.radiowaves.left.and.right")
            VStack(spacing: 0) {
                ForEach(["IEEE 802.11 standard", "Channel / band", "Signal strength (RSSI)", "Negotiated PHY rate", "Channel bandwidth"], id: \.self) { field in
                    HStack {
                        Text(field).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text("Not exposed by iOS").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.faint)
                    }
                    .padding(.vertical, 9)
                    if field != "Channel bandwidth" { Divider().overlay(Theme.glassStroke) }
                }
            }
            .padding(.horizontal, 14)
            .glassCard()
            Text("Apple removed radio-level Wi-Fi telemetry from third-party access years ago — no entitlement, permission, or App Store status changes that. GhostWire's \"Measured link quality\" on the Dashboard is the honest substitute: real latency, jitter and loss to your gateway, sampled live.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.faint)
        }
    }
}
