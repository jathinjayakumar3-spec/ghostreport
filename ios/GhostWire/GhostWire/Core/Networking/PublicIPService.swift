import Foundation

/// Public IP + edge routing info via Cloudflare's `cdn-cgi/trace` endpoint —
/// the same plain-text endpoint the 1.1.1.1 speed test page itself calls.
/// No API key, no rate-limit surprises, and it ties naturally into a
/// "speed test to 1.1.1.1" feature since it's served from Cloudflare's edge.
enum PublicIPService {

    static func fetch() async -> PublicIPInfo {
        var info = PublicIPInfo()
        guard let url = URL(string: "https://www.cloudflare.com/cdn-cgi/trace") else { return info }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let text = String(data: data, encoding: .utf8) else { return info }
            var kv: [String: String] = [:]
            for line in text.split(separator: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                kv[String(parts[0])] = String(parts[1])
            }
            info.ip = kv["ip"]
            info.countryCode = kv["loc"]
            info.colo = kv["colo"]
        } catch {
            await HistoryStore.shared.record(.warn, category: "Public IP", "Lookup failed: \(error.localizedDescription)")
        }
        return info
    }
}
