import Foundation

/// ICMP-based traceroute: sends an echo request per TTL, one TTL at a time,
/// increasing until either the destination replies (Echo Reply) or the hop
/// ceiling is hit. Built on the same unprivileged `ICMPSocket` primitives as
/// `ICMPPing` — every router along the path returns a "Time Exceeded" once
/// its TTL decrement hits zero, revealing its address.
enum TracerouteEngine {

    static func run(
        host: String,
        maxHops: Int = 30,
        probesPerHop: Int = 3,
        timeout: TimeInterval = 1.5,
        resolveHostnames: Bool = true,
        onHop: (@Sendable (TraceHop) -> Void)? = nil
    ) async -> [TraceHop] {
        guard let resolved = ICMPSocket.resolveIPv4(host) else {
            await HistoryStore.shared.record(.error, category: "Traceroute", "Could not resolve \(host)")
            return []
        }
        await HistoryStore.shared.record(.info, category: "Traceroute", "Starting traceroute to \(host) (\(resolved.ip))")

        var hops: [TraceHop] = []

        for ttl in 1...maxHops {
            guard let identity = ICMPSocket.openSocket(timeout: timeout, ttl: Int32(ttl)) else { break }
            var hop = TraceHop(ttl: ttl)
            var samples: [Double?] = []
            var replyAddr: String? = nil
            var reachedDestination = false

            for probe in 0..<probesPerHop {
                let seq = UInt16((ttl * 8 + probe) & 0xFFFF)
                let packet = ICMPSocket.buildEchoRequest(identifier: identity.identifier, sequence: seq)
                let sendStart = Date()
                var addrCopy = resolved.addr

                let sent: Int = packet.withUnsafeBytes { rawBuf -> Int in
                    withUnsafePointer(to: &addrCopy) { addrPtr -> Int in
                        addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sPtr in
                            sendto(identity.fd, rawBuf.baseAddress, rawBuf.count, 0, sPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
                guard sent > 0 else { samples.append(nil); continue }

                if let outcome = await Self.awaitHopReply(
                    fd: identity.fd, identifier: identity.identifier, sequence: seq,
                    sentAt: sendStart, deadline: timeout
                ) {
                    samples.append(outcome.rttMs)
                    if replyAddr == nil { replyAddr = outcome.fromIP }
                    if outcome.isDestination { reachedDestination = true }
                } else {
                    samples.append(nil)
                }
            }

            ICMPSocket.closeSocket(identity.fd)

            hop.samplesMs = samples
            hop.timedOut = samples.allSatisfy { $0 == nil }
            hop.ipAddress = replyAddr
            hop.isDestination = reachedDestination || replyAddr == resolved.ip

            if let ip = replyAddr, resolveHostnames {
                hop.host = await Self.reverseDNS(ip)
            }

            hops.append(hop)
            onHop?(hop)

            if hop.isDestination {
                await HistoryStore.shared.record(.success, category: "Traceroute", "Reached \(host) in \(ttl) hops")
                break
            }
        }

        if hops.last?.isDestination != true {
            await HistoryStore.shared.record(.warn, category: "Traceroute", "Did not reach \(host) within \(maxHops) hops")
        }

        return hops
    }

    private struct HopOutcome {
        let rttMs: Double
        let fromIP: String
        let isDestination: Bool
    }

    private static func awaitHopReply(
        fd: Int32, identifier: UInt16, sequence: UInt16, sentAt: Date, deadline: TimeInterval
    ) async -> HopOutcome? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var buffer = [UInt8](repeating: 0, count: 1024)

                while Date().timeIntervalSince(sentAt) < deadline {
                    var fromAddr = sockaddr_in()
                    var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                    let received = withUnsafeMutablePointer(to: &fromAddr) { addrPtr -> Int in
                        addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sPtr in
                            recvfrom(fd, &buffer, buffer.count, 0, sPtr, &fromLen)
                        }
                    }
                    guard received > 0 else {
                        continuation.resume(returning: nil)
                        return
                    }

                    var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &fromAddr.sin_addr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                    let fromIP = String(cString: ipBuf)

                    guard let parsed = ICMPSocket.parse(Data(buffer[0..<received])) else { continue }
                    let rtt = Date().timeIntervalSince(sentAt) * 1000

                    switch parsed {
                    case let .echoReply(id, seq) where id == identifier && seq == sequence:
                        continuation.resume(returning: HopOutcome(rttMs: rtt, fromIP: fromIP, isDestination: true))
                        return
                    case let .timeExceeded(id, seq) where id == identifier && seq == sequence:
                        continuation.resume(returning: HopOutcome(rttMs: rtt, fromIP: fromIP, isDestination: false))
                        return
                    case let .destinationUnreachable(id, seq, _) where id == identifier && seq == sequence:
                        continuation.resume(returning: HopOutcome(rttMs: rtt, fromIP: fromIP, isDestination: true))
                        return
                    default:
                        continue // not our probe's response — keep listening if time remains
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }

    private static func reverseDNS(_ ip: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                inet_pton(AF_INET, ip, &addr.sin_addr)

                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result: Int32 = withUnsafePointer(to: &addr) { ptr -> Int32 in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sPtr in
                        getnameinfo(sPtr, socklen_t(MemoryLayout<sockaddr_in>.size), &host, socklen_t(host.count), nil, 0, NI_NAMEREQD)
                    }
                }
                continuation.resume(returning: result == 0 ? String(cString: host) : nil)
            }
        }
    }
}
