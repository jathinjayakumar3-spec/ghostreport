import SwiftUI

struct PortScanView: View {
    @StateObject private var vm = PortScanViewModel()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 0) {
                header
                if vm.results.isEmpty {
                    emptyState
                } else {
                    resultList
                }
            }
        }
        .navigationTitle("Port Scan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "target").foregroundStyle(Theme.muted)
                TextField("Host or IP", text: $vm.target)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($fieldFocused)
                    .font(Theme.mono(15))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard()

            HStack(spacing: 10) {
                Image(systemName: "number").foregroundStyle(Theme.muted)
                TextField("Custom ports (comma-separated) — optional", text: $vm.customPortsText)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($fieldFocused)
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCard()

            GlassButton(
                title: vm.isRunning ? "Scanning… (\(vm.openCount) open)" : "Start Scan",
                icon: vm.isRunning ? nil : "play.fill",
                prominent: true,
                isLoading: vm.isRunning
            ) {
                fieldFocused = false
                if vm.isRunning { vm.stop() } else { vm.start() }
            }

            Text("Only scan hosts and networks you own or are authorized to test.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "lock.open.trianglebadge.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(Theme.faint)
            Text("TCP-connect scan across 37 common service ports, or your own list.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Spacer()
        }
    }

    private var resultList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(vm.results) { result in
                    HStack {
                        StatusPill(text: result.status.rawValue, style: pillStyle(result.status))
                            .frame(width: 84, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(result.port)").font(Theme.mono(14, weight: .bold)).foregroundStyle(Theme.ink)
                            Text(result.service).font(.system(size: 10.5)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if let latency = result.latencyMs {
                            Text(Formatters.ms(latency)).font(Theme.mono(11.5)).foregroundStyle(Theme.faint)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassCard()
                }
            }
            .padding(18)
            .padding(.bottom, 40)
        }
    }

    private func pillStyle(_ status: PortStatus) -> StatusPill.Style {
        switch status {
        case .open: return .ok
        case .closed: return .neutral
        case .filtered: return .warn
        case .scanning: return .neutral
        }
    }
}
