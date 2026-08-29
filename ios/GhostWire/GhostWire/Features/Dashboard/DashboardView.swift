import SwiftUI

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    connectionHero
                    throughputCard
                    HStack(spacing: 14) {
                        wlanCard
                        publicIPCard
                    }
                    qualityCard
                    quickTools
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .refreshable { vm.refreshNow() }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("GhostWire")
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.ink)
                Text("Network diagnostics")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Circle()
                .fill(vm.snapshot.pathStatus == "Online" ? Theme.green : Theme.rose)
                .frame(width: 9, height: 9)
                .shadow(color: (vm.snapshot.pathStatus == "Online" ? Theme.green : Theme.rose).opacity(0.7), radius: 6)
            Text(vm.snapshot.pathStatus)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink2)
        }
        .padding(.top, 4)
    }

    private var connectionHero: some View {
        let kind = vm.snapshot.primary?.kind ?? .unknown
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle().fill(Theme.signalGradient.opacity(0.22)).frame(width: 46, height: 46)
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.cyan)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.rawValue)
                        .font(Theme.display(17))
                        .foregroundStyle(Theme.ink)
                    Text(vm.snapshot.primary?.name.uppercased() ?? "NO ACTIVE INTERFACE")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                if vm.snapshot.isExpensive {
                    StatusPill(text: "Metered", style: .warn, systemImage: "dollarsign.circle")
                }
            }

            Divider().overlay(Theme.glassStroke)

            HStack(spacing: 10) {
                MetricTile(label: "Local IPv4", value: vm.snapshot.primary?.ipv4 ?? "—", icon: "network")
                MetricTile(label: "Gateway", value: vm.snapshot.gateway.routerIPv4 ?? "—", icon: "arrow.triangle.branch")
            }
        }
        .padding(16)
        .glassCard(corner: Theme.r3)
    }

    private var throughputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Live throughput", subtitle: "measured, not estimated", icon: "waveform.path.ecg")
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Download", systemImage: "arrow.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.cyan)
                    Text(Formatters.kbps(vm.snapshot.throughputDownKbps)).font(Theme.mono(18, weight: .bold)).foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("Upload", systemImage: "arrow.up").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.violet)
                    Text(Formatters.kbps(vm.snapshot.throughputUpKbps)).font(Theme.mono(18, weight: .bold)).foregroundStyle(Theme.ink)
                }
                Spacer()
            }
            if vm.downloadSparkline.count > 1 {
                Sparkline(samples: vm.downloadSparkline, color: Theme.cyan)
                    .frame(height: 46)
            } else {
                Text("Collecting samples…").font(.system(size: 11)).foregroundStyle(Theme.faint).frame(height: 46)
            }
        }
        .padding(16)
        .glassCard(corner: Theme.r3)
    }

    private var wlanCard: some View {
        NavigationLink {
            WLANDetailView(vm: vm)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "wifi").foregroundStyle(Theme.cyan)
                    Text("Wi-Fi").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.faint)
                }
                Text(vm.snapshot.wifi.ssid ?? "Not on Wi-Fi")
                    .font(Theme.display(15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let secure = vm.snapshot.wifi.isSecure {
                    StatusPill(text: secure ? "Secured" : "Open", style: secure ? .ok : .bad)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var publicIPCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "globe").foregroundStyle(Theme.violet)
                Text("Public IP").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                Spacer()
            }
            Text(vm.snapshot.publicIP.ip ?? "—")
                .font(Theme.mono(15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let country = vm.snapshot.publicIP.countryCode {
                Text("via \(vm.snapshot.publicIP.colo ?? "—") · \(country)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var qualityCard: some View {
        let score = vm.gatewayPing?.qualityScore ?? 0
        let color = Theme.quality(score)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Measured link quality", subtitle: "to gateway", icon: "gauge.with.dots.needle.67percent")
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: score)
                        .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring, value: score)
                    Text(Formatters.pct(score * 100))
                        .font(Theme.mono(13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 5) {
                    KeyValueRow(key: "Avg RTT", value: Formatters.ms(vm.gatewayPing?.avgMs), valueColor: color)
                    KeyValueRow(key: "Jitter", value: Formatters.ms(vm.gatewayPing?.jitterMs))
                    KeyValueRow(key: "Loss", value: Formatters.pct(vm.gatewayPing?.packetLossPct ?? 0))
                }
            }
            Text("Wi-Fi signal strength, channel and PHY rate are not exposed by any public iOS API — this score is a real measurement of round-trip latency, jitter and loss to your gateway instead of a fabricated radio reading.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.faint)
        }
        .padding(16)
        .glassCard(corner: Theme.r3)
    }

    private var quickTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Diagnostics", icon: "wrench.and.screwdriver")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ToolTile(title: "Speed Test", subtitle: "to 1.1.1.1", icon: "speedometer", accent: Theme.cyan) { SpeedTestView() }
                ToolTile(title: "Traceroute", subtitle: "hop-by-hop path", icon: "point.topleft.down.curvedto.point.bottomright.up", accent: Theme.violet) { TracerouteView() }
                ToolTile(title: "DNS Lookup", subtitle: "any record type", icon: "server.rack", accent: Theme.amber) { DNSLookupView() }
                ToolTile(title: "Ping", subtitle: "custom host", icon: "dot.radiowaves.left.and.right", accent: Theme.green) { PingView() }
                ToolTile(title: "Port Scan", subtitle: "TCP connect scan", icon: "lock.open.trianglebadge.exclamationmark", accent: Theme.rose) { PortScanView() }
                ToolTile(title: "WHOIS", subtitle: "domain / IP", icon: "doc.text.magnifyingglass", accent: Theme.cyanLift) { WHOISView() }
            }
        }
    }
}
