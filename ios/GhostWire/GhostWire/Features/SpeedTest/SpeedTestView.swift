import SwiftUI

struct SpeedTestView: View {
    @StateObject private var vm = SpeedTestViewModel()

    private var isDownloadPhase: Bool { vm.result.phase == .download }
    private var gaugeValue: Double {
        switch vm.result.phase {
        case .download: return vm.result.liveSamples.last ?? 0
        case .upload: return vm.result.liveSamples.last ?? 0
        case .done: return vm.result.downloadMbps
        default: return 0
        }
    }
    private var gaugeAccent: Color { isDownloadPhase ? Theme.cyan : Theme.violet }
    private var gaugeLabel: String {
        switch vm.result.phase {
        case .idle: return "Ready"
        case .latency: return "Latency"
        case .download: return "Download"
        case .upload: return "Upload"
        case .done: return "Download"
        case .failed: return "Failed"
        }
    }

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(spacing: 20) {
                    Text("Speed Test").font(Theme.display(24)).foregroundStyle(Theme.ink).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Cloudflare speed.cloudflare.com · latency to 1.1.1.1")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)

                    RadialGauge(value: gaugeValue, maxValue: max(200, gaugeValue * 1.2), unit: "Mbps", label: gaugeLabel, accent: gaugeAccent)
                        .frame(width: 220, height: 220)
                        .padding(.top, 6)

                    if !vm.result.liveSamples.isEmpty && vm.isRunning {
                        Sparkline(samples: vm.result.liveSamples, color: gaugeAccent)
                            .frame(height: 50)
                            .padding(.horizontal, 8)
                    }

                    HStack(spacing: 12) {
                        MetricTile(label: "Download", value: Formatters.mbps(vm.result.downloadMbps), icon: "arrow.down.circle.fill", accent: Theme.cyan)
                        MetricTile(label: "Upload", value: Formatters.mbps(vm.result.uploadMbps), icon: "arrow.up.circle.fill", accent: Theme.violet)
                    }
                    HStack(spacing: 12) {
                        MetricTile(label: "Ping", value: Formatters.ms(vm.result.pingMs), icon: "timer", accent: Theme.amber)
                        MetricTile(label: "Jitter", value: Formatters.ms(vm.result.jitterMs), icon: "waveform.path", accent: Theme.green)
                        MetricTile(label: "Loss", value: Formatters.pct(vm.result.packetLossPct), icon: "exclamationmark.triangle", accent: Theme.rose)
                    }

                    GlassButton(
                        title: vm.isRunning ? statusText : "Start Speed Test",
                        icon: vm.isRunning ? nil : "play.fill",
                        prominent: true,
                        isLoading: vm.isRunning
                    ) {
                        vm.start()
                    }

                    if !vm.history.isEmpty {
                        historySection
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.loadHistory() }
    }

    private var statusText: String {
        vm.result.phase.rawValue
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Recent tests", icon: "clock.arrow.circlepath")
            VStack(spacing: 0) {
                ForEach(Array(vm.history.prefix(8).enumerated()), id: \.offset) { i, item in
                    if i > 0 { Divider().overlay(Theme.glassStroke) }
                    HStack {
                        Text(Formatters.relativeTime(item.timestamp))
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                        Spacer()
                        Label(Formatters.mbps(item.downloadMbps), systemImage: "arrow.down")
                            .font(Theme.mono(12)).foregroundStyle(Theme.cyan)
                        Label(Formatters.mbps(item.uploadMbps), systemImage: "arrow.up")
                            .font(Theme.mono(12)).foregroundStyle(Theme.violet)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 14)
            .glassCard()
        }
    }
}
