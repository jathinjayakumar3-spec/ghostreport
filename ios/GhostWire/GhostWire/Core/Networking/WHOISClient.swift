import Foundation
import Network

/// Minimal WHOIS (RFC 3912) client over a raw TCP/43 connection via
/// `Network.framework`. Starts at IANA's root WHOIS server, follows its
/// "refer" pointer to the registry's authoritative server for the TLD, and
/// returns that server's full response — the same two-hop lookup `whois`
/// on a desktop performs.
enum WHOISClient {

    static func lookup(_ query: String) async -> WHOISResult {
        var result = WHOISResult(query: query)
        let target = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let ianaText = await send(query: target, to: "whois.iana.org") else {
            result.errorMessage = "Could not reach whois.iana.org"
            await HistoryStore.shared.record(.error, category: "WHOIS", "IANA referral lookup failed for \(target)")
            return result
        }

        if let referral = extractReferral(from: ianaText) {
            if let finalText = await send(query: target, to: referral) {
                result.raw = finalText
                result.server = referral
            } else {
                result.raw = ianaText
                result.server = "whois.iana.org"
            }
        } else {
            result.raw = ianaText
            result.server = "whois.iana.org"
        }

        await HistoryStore.shared.record(.success, category: "WHOIS", "Looked up \(target) via \(result.server)")
        return result
    }

    private static func extractReferral(from text: String) -> String? {
        for line in text.split(separator: "\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("whois:") || lower.hasPrefix("refer:") {
                let value = line.split(separator: ":", maxSplits: 1)[1]
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func send(query: String, to host: String, timeout: TimeInterval = 8) async -> String? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: 43, using: .tcp)
            var buffer = Data()
            var resumed = false
            let lock = NSLock()

            func finish(_ value: String?) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            func receiveLoop() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    if let data { buffer.append(data) }
                    if isComplete || error != nil {
                        finish(String(data: buffer, encoding: .utf8) ?? String(decoding: buffer, as: UTF8.self))
                    } else {
                        receiveLoop()
                    }
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let payload = (query + "\r\n").data(using: .utf8) ?? Data()
                    connection.send(content: payload, completion: .contentProcessed { _ in
                        receiveLoop()
                    })
                case .failed, .cancelled:
                    finish(buffer.isEmpty ? nil : String(decoding: buffer, as: UTF8.self))
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(buffer.isEmpty ? nil : String(decoding: buffer, as: UTF8.self))
            }
        }
    }
}
