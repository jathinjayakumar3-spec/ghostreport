import Foundation

@MainActor
final class WHOISViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var result: WHOISResult?
    @Published var isRunning = false

    func run() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isRunning else { return }
        isRunning = true
        Task { [weak self] in
            let r = await WHOISClient.lookup(q)
            await MainActor.run {
                self?.result = r
                self?.isRunning = false
            }
        }
    }
}
