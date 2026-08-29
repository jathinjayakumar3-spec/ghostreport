import Foundation

@MainActor
final class TracerouteViewModel: ObservableObject {
    @Published var target: String = "1.1.1.1"
    @Published var hops: [TraceHop] = []
    @Published var isRunning = false
    @Published var resolveHostnames = true
    @Published var didFinish = false

    private var task: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        let host = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }

        isRunning = true
        didFinish = false
        hops = []

        task = Task { [weak self, resolveHostnames] in
            _ = await TracerouteEngine.run(host: host, resolveHostnames: resolveHostnames) { hop in
                Task { @MainActor in
                    self?.appendOrReplace(hop)
                }
            }
            await MainActor.run {
                self?.isRunning = false
                self?.didFinish = true
            }
        }
    }

    func cancel() {
        task?.cancel()
        isRunning = false
    }

    private func appendOrReplace(_ hop: TraceHop) {
        if let idx = hops.firstIndex(where: { $0.ttl == hop.ttl }) {
            hops[idx] = hop
        } else {
            hops.append(hop)
        }
    }
}
