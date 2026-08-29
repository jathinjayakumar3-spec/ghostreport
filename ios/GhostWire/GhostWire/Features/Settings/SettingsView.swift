import SwiftUI

struct SettingsView: View {
    @AppStorage("gw.defaultPingHost") private var defaultPingHost = "1.1.1.1"
    @AppStorage("gw.defaultTraceHost") private var defaultTraceHost = "1.1.1.1"
    @AppStorage("gw.resolveHostnames") private var resolveHostnames = true

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    defaultsCard
                    aboutCard
                    limitationsCard
                }
                .padding(18)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var defaultsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Defaults", icon: "slider.horizontal.3")
            VStack(spacing: 0) {
                settingsField("Default ping target", text: $defaultPingHost)
                Divider().overlay(Theme.glassStroke)
                settingsField("Default traceroute target", text: $defaultTraceHost)
                Divider().overlay(Theme.glassStroke)
                Toggle(isOn: $resolveHostnames) {
                    Text("Reverse-resolve hop hostnames").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink2)
                }
                .tint(Theme.cyan)
                .padding(.vertical, 9)
            }
            .padding(.horizontal, 14)
            .glassCard()
        }
    }

    private func settingsField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
            Spacer()
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 9)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "About", icon: "info.circle")
            VStack(spacing: 0) {
                KeyValueRow(key: "App", value: "GhostWire", monospace: false)
                Divider().overlay(Theme.glassStroke)
                KeyValueRow(key: "Version", value: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0", monospace: false)
                Divider().overlay(Theme.glassStroke)
                KeyValueRow(key: "Speed test server", value: "speed.cloudflare.com")
                Divider().overlay(Theme.glassStroke)
                KeyValueRow(key: "Latency target", value: "1.1.1.1")
            }
            .padding(.horizontal, 14)
            .glassCard()
        }
    }

    private var limitationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Platform limitations", icon: "exclamationmark.shield")
            VStack(alignment: .leading, spacing: 10) {
                limitRow("No RSSI / channel / PHY rate", "iOS has never exposed Wi-Fi radio telemetry to third-party apps, entitled or not. Any app claiming otherwise is estimating.")
                limitRow("No raw packet capture", "Full packet capture needs a Network Extension (Packet Tunnel Provider) with an Apple-granted entitlement and a device-wide VPN profile — out of scope for a diagnostics utility like this.")
                limitRow("ICMP works without root", "Ping and traceroute use the same unprivileged \"ping socket\" technique as Apple's own sample code — real ICMP, no jailbreak needed.")
            }
            .padding(16)
            .glassCard(corner: Theme.r3)
        }
    }

    private func limitRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.ink2)
            Text(detail).font(.system(size: 11)).foregroundStyle(Theme.faint)
        }
    }
}
