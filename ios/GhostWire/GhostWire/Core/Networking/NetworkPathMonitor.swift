import Foundation
import Network
import Combine

/// Thin, observable wrapper around `NWPathMonitor` — the standard public API
/// for path/interface/expensive-constrained status. Publishes changes and
/// mirrors every transition into the diagnostics log.
@MainActor
final class NetworkPathMonitorService: ObservableObject {
    static let shared = NetworkPathMonitorService()

    @Published private(set) var isSatisfied: Bool = false
    @Published private(set) var isExpensive: Bool = false
    @Published private(set) var isConstrained: Bool = false
    @Published private(set) var currentKind: ConnectionKind = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.ghostwire.pathmonitor")
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let kind: ConnectionKind
            if path.usesInterfaceType(.wifi) { kind = .wifi }
            else if path.usesInterfaceType(.cellular) { kind = .cellular }
            else if path.usesInterfaceType(.wiredEthernet) { kind = .wiredEthernet }
            else if path.usesInterfaceType(.other) { kind = .vpn }
            else { kind = .unknown }

            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasSatisfied = self.isSatisfied
                self.isSatisfied = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained
                self.currentKind = kind

                if wasSatisfied != self.isSatisfied {
                    HistoryStore.shared.record(
                        self.isSatisfied ? .success : .error,
                        category: "Path",
                        self.isSatisfied ? "Network became reachable via \(kind.rawValue)" : "Network became unreachable"
                    )
                }
            }
        }
        monitor.start(queue: queue)
    }
}
