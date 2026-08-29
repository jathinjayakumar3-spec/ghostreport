import SwiftUI

/// Full catalogue of diagnostic tools — the "professional level" toolbox
/// beyond the Dashboard's quick actions.
struct ToolsHomeView: View {
    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tools").font(Theme.display(26)).foregroundStyle(Theme.ink)
                        Text("Every diagnostic in one place").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                    }

                    group(title: "Performance") {
                        ToolTile(title: "Speed Test", subtitle: "Download / upload to Cloudflare, latency to 1.1.1.1", icon: "speedometer", accent: Theme.cyan) { SpeedTestView() }
                        ToolTile(title: "Ping", subtitle: "Continuous or fixed-count ICMP echo", icon: "dot.radiowaves.left.and.right", accent: Theme.green) { PingView() }
                    }

                    group(title: "Path & Routing") {
                        ToolTile(title: "Traceroute", subtitle: "Hop-by-hop ICMP TTL trace with reverse DNS", icon: "point.topleft.down.curvedto.point.bottomright.up", accent: Theme.violet) { TracerouteView() }
                        ToolTile(title: "Port Scan", subtitle: "TCP-connect scan of common or custom ports", icon: "lock.open.trianglebadge.exclamationmark", accent: Theme.rose) { PortScanView() }
                    }

                    group(title: "Naming & Ownership") {
                        ToolTile(title: "DNS Lookup", subtitle: "A · AAAA · MX · TXT · NS · SOA · SRV · CAA", icon: "server.rack", accent: Theme.amber) { DNSLookupView() }
                        ToolTile(title: "WHOIS", subtitle: "Registry lookup via IANA referral", icon: "doc.text.magnifyingglass", accent: Theme.cyanLift) { WHOISView() }
                    }

                    group(title: "This device") {
                        ToolTile(title: "Wi-Fi & Interfaces", subtitle: "SSID, IP config, gateway, DNS servers", icon: "wifi", accent: Theme.violetLift) { WLANDetailView(vm: DashboardViewModel()) }
                        ToolTile(title: "Diagnostics Log", subtitle: "Every probe this session, exportable", icon: "doc.text", accent: Theme.muted) { DiagnosticsLogView() }
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                content()
            }
        }
    }
}
