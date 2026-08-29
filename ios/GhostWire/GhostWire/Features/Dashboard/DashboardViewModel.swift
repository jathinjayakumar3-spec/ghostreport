import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var snapshot = NetworkSnapshot()
    @Published var downloadSparkline: [Double] = []
    @Published var uploadSparkline: [Double] = []
    @Published var gatewayPing: PingSummary?
    @Published var isRefreshing = false

    private var lastCounters: (rx: UInt64, tx: UInt64, at: Date)?
    private var refreshTask: Task<Void, Never>?
    private let path = NetworkPathMonitorService.shared

    func start() {
        path.start()
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshNow() {
        Task { await refresh() }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let interfaces = InterfaceInfo.currentInterfaces()
        let primary = InterfaceInfo.primaryInterface(from: interfaces)
        let wifi = await WiFiInfoProvider.current()
        let gateway = SystemNetworkConfig.gatewayInfo()

        snapshot.allInterfaces = interfaces
        snapshot.primary = primary
        snapshot.wifi = wifi
        snapshot.gateway = gateway
        snapshot.pathStatus = path.isSatisfied ? "Online" : "Offline"
        snapshot.isExpensive = path.isExpensive
        snapshot.isConstrained = path.isConstrained

        updateThroughput(interfaceName: primary?.name)

        // Public IP is slower / rate-sensitive — refresh less aggressively.
        if snapshot.publicIP.ip == nil {
            snapshot.publicIP = await PublicIPService.fetch()
        }

        // A light gateway ping doubles as the "measured link quality" input.
        if let router = gateway.routerIPv4 {
            let summary = await ICMPPing.run(host: router, count: 3, timeout: 1.0, interval: 0.1)
            gatewayPing = summary
        }
    }

    private func updateThroughput(interfaceName: String?) {
        guard let name = interfaceName, let counters = InterfaceInfo.byteCounters(for: name) else {
            lastCounters = nil
            return
        }
        let now = Date()
        defer { lastCounters = (counters.rx, counters.tx, now) }

        guard let last = lastCounters else { return }
        let dt = now.timeIntervalSince(last.at)
        guard dt > 0.1, counters.rx >= last.rx, counters.tx >= last.tx else { return }

        let rxKbps = Double(counters.rx - last.rx) * 8 / dt / 1000
        let txKbps = Double(counters.tx - last.tx) * 8 / dt / 1000
        snapshot.throughputDownKbps = rxKbps
        snapshot.throughputUpKbps = txKbps

        downloadSparkline.append(rxKbps)
        uploadSparkline.append(txKbps)
        if downloadSparkline.count > 40 { downloadSparkline.removeFirst() }
        if uploadSparkline.count > 40 { uploadSparkline.removeFirst() }
    }
}
