import Foundation

@MainActor
final class SpeedTestViewModel: ObservableObject {
    @Published var result = SpeedTestResult()
    @Published var isRunning = false
    @Published var history: [SpeedTestResult] = []

    private var task: Task<Void, Never>?

    func loadHistory() {
        history = Array(HistoryStore.shared.speedTestHistory.suffix(20).reversed())
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        result = SpeedTestResult()
        let engine = SpeedTestEngine()

        task = Task { [weak self] in
            let final = await engine.run { partial in
                Task { @MainActor in
                    self?.result = partial
                }
            }
            await MainActor.run {
                self?.result = final
                self?.isRunning = false
                self?.loadHistory()
            }
        }
    }

    func cancel() {
        task?.cancel()
        isRunning = false
    }
}
