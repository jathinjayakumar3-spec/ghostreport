import SwiftUI

struct TracerouteView: View {
    @StateObject private var vm = TracerouteViewModel()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 0) {
                header
                if vm.hops.isEmpty && !vm.isRunning {
                    emptyState
                } else {
                    hopList
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Traceroute")
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .foregroundStyle(Theme.muted)
                TextField("Host or IP", text: $vm.target)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($fieldFocused)
                    .font(Theme.mono(15))
                    .foregroundStyle(Theme.ink)
                Toggle("", isOn: $vm.resolveHostnames)
                    .labelsHidden()
                    .tint(Theme.cyan)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard()

            GlassButton(
                title: vm.isRunning ? "Tracing… (\(vm.hops.count) hops)" : "Start Traceroute",
                icon: vm.isRunning ? nil : "play.fill",
                prominent: true,
                isLoading: vm.isRunning
            ) {
                fieldFocused = false
                if vm.isRunning { vm.cancel() } else { vm.start() }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 34))
                .foregroundStyle(Theme.faint)
            Text("Trace the path to any host, hop by hop, with real ICMP TTL probes.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Spacer()
        }
    }

    private var hopList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(vm.hops) { hop in
                    HopRow(hop: hop)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 2)
                        .glassCard()
                }
                if vm.didFinish {
                    Text(vm.hops.last?.isDestination == true ? "Destination reached." : "Max hops reached without a reply from the destination.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.faint)
                        .padding(.top, 6)
                }
            }
            .padding(18)
            .padding(.bottom, 40)
        }
    }
}
