import Foundation

@MainActor
final class DNSLookupViewModel: ObservableObject {
    @Published var queryName: String = "cloudflare.com"
    @Published var selectedType: DNSRecordType = .a
    @Published var summary: DNSLookupSummary?
    @Published var isRunning = false

    func run() {
        let name = queryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isRunning else { return }
        isRunning = true
        let type = selectedType

        Task { [weak self] in
            let result = await DNSResolver.query(name: name, type: type)
            await MainActor.run {
                self?.summary = result
                self?.isRunning = false
            }
        }
    }
}
