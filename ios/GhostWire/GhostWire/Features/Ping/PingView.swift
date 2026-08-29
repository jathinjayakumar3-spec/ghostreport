import SwiftUI

struct PingView: View {
    @StateObject private var vm = PingViewModel()
    @FocusState private var fieldFocused: Bool

    private var rttSamples: [Double] {
        vm.samples.map { $0.rttMs ?? 0 }
    }

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(spacing: 18) {
                    inputCard
                    if let summary = vm.summary {
                        statsGrid(summary)
                    }
                    if !vm.samples.isEmpty {
                        Sparkline(samples: rttSamples, color: Theme.green)
                            .frame(height: 60)
                            .padding(14)
                            .glassCard()
                        sampleList
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Ping")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Theme.muted)
                TextField("Host or IP", text: $vm.target)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($fieldFocused)
                    .font(Theme.mono(15))
                    .foregroundStyle(Theme.ink)
                Toggle(isOn: $vm.continuous) {
                    Text("Continuous").font(.system(size: 11, weight: .semibold))
                }
                .toggleStyle(.button)
                .tint(Theme.cyan)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard()

            GlassButton(
                title: vm.isRunning ? "Stop" : "Start Ping",
                icon: vm.isRunning ? "stop.fill" : "play.fill",
                prominent: true,
                isLoading: false
            ) {
                fieldFocused = false
                if vm.isRunning { vm.stop() } else { vm.start() }
            }
        }
    }

    private func statsGrid(_ summary: PingSummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                MetricTile(label: "Min", value: Formatters.ms(summary.minMs), accent: Theme.green)
                MetricTile(label: "Avg", value: Formatters.ms(summary.avgMs), accent: Theme.cyan)
                MetricTile(label: "Max", value: Formatters.ms(summary.maxMs), accent: Theme.amber)
            }
            HStack(spacing: 10) {
                MetricTile(label: "Jitter", value: Formatters.ms(summary.jitterMs), icon: "waveform.path")
                MetricTile(label: "Loss", value: Formatters.pct(summary.packetLossPct), icon: "exclamationmark.triangle",
                           accent: summary.packetLossPct > 0 ? Theme.rose : Theme.green)
                MetricTile(label: "Sent/Recv", value: "\(summary.received)/\(summary.sent)", icon: "arrow.left.arrow.right")
            }
        }
    }

    private var sampleList: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Probes", icon: "list.bullet")
            VStack(spacing: 0) {
                ForEach(Array(vm.samples.suffix(12).reversed())) { sample in
                    HStack {
                        Text("seq \(sample.sequence)").font(Theme.mono(11.5)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(sample.rttMs != nil ? Formatters.ms(sample.rttMs) : "timeout")
                            .font(Theme.mono(12.5, weight: .semibold))
                            .foregroundStyle(sample.rttMs != nil ? Theme.ink : Theme.rose)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 14)
            .glassCard()
        }
    }
}
