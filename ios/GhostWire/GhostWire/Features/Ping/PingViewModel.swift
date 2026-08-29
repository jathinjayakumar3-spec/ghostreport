import Foundation

@MainActor
final class PingViewModel: ObservableObject {
    @Published var target: String = "1.1.1.1"
    @Published var samples: [PingSample] = []
    @Published var summary: PingSummary?
    @Published var isRunning = false
    @Published var continuous = false

    private var task: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        let host = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }

        isRunning = true
        samples = []
        summary = nil

        task = Task { [weak self] in
            while true {
                guard let self, !Task.isCancelled else { break }
                let result = await ICMPPing.run(host: host, count: 10, timeout: 1.5, interval: 0.3) { sample in
                    Task { @MainActor in
                        self.samples.append(sample)
                        if self.samples.count > 200 { self.samples.removeFirst() }
                    }
                }
                guard !Task.isCancelled else { break }
                await MainActor.run { self.summary = result }
                guard self.continuous else { break }
            }
            await MainActor.run { self?.isRunning = false }
        }
    }

    func stop() {
        task?.cancel()
        isRunning = false
    }
}
