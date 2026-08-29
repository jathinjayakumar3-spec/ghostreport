import Foundation

@MainActor
final class PortScanViewModel: ObservableObject {
    @Published var target: String = ""
    @Published var results: [PortScanResult] = []
    @Published var isRunning = false
    @Published var customPortsText: String = ""

    private var task: Task<Void, Never>?

    var openCount: Int { results.filter { $0.status == .open }.count }

    func start() {
        guard !isRunning else { return }
        let host = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }

        let ports = customPorts() ?? PortScanner.commonPorts
        isRunning = true
        results = ports.map { PortScanResult(port: $0.port, service: $0.service, status: .scanning, latencyMs: nil) }

        task = Task { [weak self] in
            await PortScanner.scan(host: host, ports: ports) { result in
                Task { @MainActor in
                    guard let idx = self?.results.firstIndex(where: { $0.port == result.port }) else { return }
                    self?.results[idx] = result
                }
            }
            await MainActor.run { self?.isRunning = false }
        }
    }

    func stop() {
        task?.cancel()
        isRunning = false
    }

    private func customPorts() -> [PortDefinition]? {
        let trimmed = customPortsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let ports = trimmed
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && $0 <= 65535 }
        guard !ports.isEmpty else { return nil }
        return ports.map { port in
            PortDefinition(port: port, service: PortScanner.commonPorts.first { $0.port == port }?.service ?? "Custom")
        }
    }
}
