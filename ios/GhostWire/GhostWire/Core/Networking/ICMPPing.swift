import Foundation

/// High-level ICMP ping engine built on `ICMPSocket`'s unprivileged
/// primitives. Used standalone by the Ping tool and as the latency/jitter/
/// loss stage of the speed test.
enum ICMPPing {

    /// Runs a sequence of echo requests against `host`, invoking `onSample`
    /// after every probe (success or timeout), and returns the aggregate
    /// summary once all probes complete.
    static func run(
        host: String,
        count: Int = 5,
        timeout: TimeInterval = 2.0,
        interval: TimeInterval = 0.35,
        onSample: (@Sendable (PingSample) -> Void)? = nil
    ) async -> PingSummary {
        var summary = PingSummary()
        summary.host = host

        guard let resolved = ICMPSocket.resolveIPv4(host) else {
            await HistoryStore.shared.record(.error, category: "Ping", "Could not resolve \(host)")
            return summary
        }
        summary.resolvedIP = resolved.ip

        guard let identity = ICMPSocket.openSocket(timeout: timeout) else {
            await HistoryStore.shared.record(.error, category: "Ping", "Could not open ICMP socket")
            return summary
        }
        defer { ICMPSocket.closeSocket(identity.fd) }

        var rtts: [Double] = []
        let destAddr = resolved.addr

        for seq in 0..<count {
            summary.sent += 1
            let packet = ICMPSocket.buildEchoRequest(identifier: identity.identifier, sequence: UInt16(seq))
            let sendStart = Date()
            var addrCopy = destAddr

            let sent: Int = packet.withUnsafeBytes { rawBuf -> Int in
                withUnsafePointer(to: &addrCopy) { addrPtr -> Int in
                    addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sPtr in
                        sendto(identity.fd, rawBuf.baseAddress, rawBuf.count, 0, sPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }

            var rttMs: Double? = nil
            if sent > 0 {
                rttMs = await Self.awaitEchoReply(
                    fd: identity.fd, identifier: identity.identifier, sequence: UInt16(seq),
                    sentAt: sendStart, deadline: timeout
                )
            }

            let sample = PingSample(sequence: seq, rttMs: rttMs, ttl: nil, timestamp: Date())
            if let rttMs { rtts.append(rttMs); summary.received += 1 }
            onSample?(sample)

            if seq < count - 1 {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }

        if !rtts.isEmpty {
            summary.minMs = rtts.min() ?? 0
            summary.maxMs = rtts.max() ?? 0
            summary.avgMs = rtts.reduce(0, +) / Double(rtts.count)
            if rtts.count > 1 {
                let diffs = zip(rtts, rtts.dropFirst()).map { abs($1 - $0) }
                summary.jitterMs = diffs.reduce(0, +) / Double(diffs.count)
            }
        }
        summary.packetLossPct = summary.sent > 0
            ? (Double(summary.sent - summary.received) / Double(summary.sent)) * 100
            : 0

        await HistoryStore.shared.record(
            .info, category: "Ping",
            "\(host): \(summary.received)/\(summary.sent) received, avg \(String(format: "%.1f", summary.avgMs))ms, loss \(String(format: "%.0f", summary.packetLossPct))%"
        )

        return summary
    }

    /// Blocks (on a background queue) until either our matching echo reply
    /// arrives or the deadline for this probe elapses.
    private static func awaitEchoReply(
        fd: Int32, identifier: UInt16, sequence: UInt16, sentAt: Date, deadline: TimeInterval
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var buffer = [UInt8](repeating: 0, count: 512)

                while Date().timeIntervalSince(sentAt) < deadline {
                    var fromAddr = sockaddr_in()
                    var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                    let received = withUnsafeMutablePointer(to: &fromAddr) { addrPtr -> Int in
                        addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sPtr in
                            recvfrom(fd, &buffer, buffer.count, 0, sPtr, &fromLen)
                        }
                    }
                    guard received > 0 else {
                        continuation.resume(returning: nil) // timed out (EWOULDBLOCK) or socket error
                        return
                    }
                    guard let parsed = ICMPSocket.parse(Data(buffer[0..<received])) else { continue }
                    if case let .echoReply(id, seq) = parsed, id == identifier, seq == sequence {
                        continuation.resume(returning: Date().timeIntervalSince(sentAt) * 1000)
                        return
                    }
                    // A stray/late reply from an earlier probe — keep waiting for ours.
                }
                continuation.resume(returning: nil)
            }
        }
    }
}
