import Foundation
import Darwin

/// Low-level unprivileged-ICMP primitives shared by `ICMPPing` and
/// `TracerouteEngine`.
///
/// iOS/macOS's kernel allows ordinary, non-root apps to open
/// `socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)` — a "ping socket" — and send
/// real ICMP Echo Requests without any special entitlement. This is the
/// exact technique Apple's own "SimplePing" sample code uses, and it's what
/// every legitimate iOS ping/traceroute app is built on (there is no raw
/// `SOCK_RAW` access without root, which the iOS sandbox never grants).
enum ICMPSocket {

    struct EchoIdentity {
        let fd: Int32
        let identifier: UInt16
    }

    enum ParsedMessage {
        case echoReply(identifier: UInt16, sequence: UInt16)
        case timeExceeded(identifier: UInt16, sequence: UInt16)
        case destinationUnreachable(identifier: UInt16, sequence: UInt16, code: UInt8)
        case other(type: UInt8, code: UInt8)
    }

    // MARK: Address resolution

    /// Resolves a hostname (or dotted IPv4 literal) to its first IPv4 address.
    static func resolveIPv4(_ host: String) -> (ip: String, addr: sockaddr_in)? {
        var hints = addrinfo(
            ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_DGRAM,
            ai_protocol: IPPROTO_ICMP, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil
        )
        var resultPtr: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &resultPtr)
        guard status == 0, let first = resultPtr else { return nil }
        defer { freeaddrinfo(resultPtr) }
        guard let sa = first.pointee.ai_addr else { return nil }

        let addr: sockaddr_in = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }

        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var mutableAddr = addr.sin_addr
        inet_ntop(AF_INET, &mutableAddr, &buf, socklen_t(INET_ADDRSTRLEN))
        return (String(cString: buf), addr)
    }

    // MARK: Socket lifecycle

    static func openSocket(timeout: TimeInterval, ttl: Int32? = nil) -> EchoIdentity? {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else { return nil }

        var tv = timeval(tv_sec: Int(timeout), tv_usec: __darwin_suseconds_t((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        if var ttlValue = ttl {
            setsockopt(fd, IPPROTO_IP, IP_TTL, &ttlValue, socklen_t(MemoryLayout<Int32>.size))
        }

        // Force immediate ephemeral-port assignment (rather than the lazy
        // assignment that would otherwise happen on first send) so the
        // identifier we read back via getsockname below is the one the
        // kernel will actually stamp on every packet from this socket.
        var localAddr = sockaddr_in()
        localAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        localAddr.sin_family = sa_family_t(AF_INET)
        localAddr.sin_port = 0
        localAddr.sin_addr.s_addr = INADDR_ANY
        withUnsafePointer(to: &localAddr) { ptr -> Void in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sPtr in
                _ = bind(fd, sPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        // The kernel stamps outgoing DGRAM-ICMP packets with the socket's
        // bound local port as the ICMP identifier — read it back so we know
        // what to match on replies.
        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let identifier: UInt16
        withUnsafeMutablePointer(to: &boundAddr) { ptr -> Void in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sPtr in
                _ = getsockname(fd, sPtr, &len)
            }
        }
        if boundAddr.sin_port != 0 {
            // sin_port is stored in network byte order; the kernel uses this
            // same value (also network order) as the packet's ICMP identifier.
            identifier = UInt16(bigEndian: boundAddr.sin_port)
        } else {
            identifier = UInt16.random(in: 1...0xFFFF)
        }
        return EchoIdentity(fd: fd, identifier: identifier)
    }

    static func closeSocket(_ fd: Int32) {
        close(fd)
    }

    // MARK: Packet construction

    static func buildEchoRequest(identifier: UInt16, sequence: UInt16, payloadSize: Int = 32) -> Data {
        var packet = Data(count: 8 + payloadSize)
        packet[0] = 8   // ICMP Echo Request
        packet[1] = 0
        packet[2] = 0   // checksum placeholder
        packet[3] = 0
        packet.replaceSubrange(4..<6, with: withUnsafeBytes(of: identifier.bigEndian) { Data($0) })
        packet.replaceSubrange(6..<8, with: withUnsafeBytes(of: sequence.bigEndian) { Data($0) })
        for i in 0..<payloadSize {
            packet[8 + i] = UInt8((i &+ 65) & 0xFF) // "A", "B", "C"… filler, same idea as classic ping
        }
        let sum = checksum(packet)
        packet.replaceSubrange(2..<4, with: withUnsafeBytes(of: sum.bigEndian) { Data($0) })
        return packet
    }

    static func checksum(_ data: Data) -> UInt16 {
        var sum: UInt32 = 0
        var bytes = Array(data)
        if bytes.count % 2 != 0 { bytes.append(0) }
        var i = 0
        while i < bytes.count {
            let word = (UInt32(bytes[i]) << 8) | UInt32(bytes[i + 1])
            sum &+= word
            i += 2
        }
        while (sum >> 16) != 0 {
            sum = (sum & 0xFFFF) &+ (sum >> 16)
        }
        return ~UInt16(sum & 0xFFFF)
    }

    // MARK: Response parsing

    /// Parses a datagram received on a `SOCK_DGRAM`/`IPPROTO_ICMP` socket.
    /// Unlike raw ICMP sockets, the kernel already strips the IP header from
    /// the *outer* delivery — but ICMP error messages (Time Exceeded,
    /// Destination Unreachable) still embed a copy of the original IP header
    /// + our original 8-byte echo header, which we must skip past to recover
    /// our identifier/sequence for matching.
    static func parse(_ data: Data) -> ParsedMessage? {
        guard data.count >= 8 else { return nil }
        let bytes = [UInt8](data)
        let type = bytes[0]
        let code = bytes[1]

        switch type {
        case 0: // Echo Reply
            let identifier = UInt16(bytes[4]) << 8 | UInt16(bytes[5])
            let sequence = UInt16(bytes[6]) << 8 | UInt16(bytes[7])
            return .echoReply(identifier: identifier, sequence: sequence)

        case 11: // Time Exceeded
            guard let (id, seq) = extractEmbeddedEcho(bytes) else { return .other(type: type, code: code) }
            return .timeExceeded(identifier: id, sequence: seq)

        case 3: // Destination Unreachable
            guard let (id, seq) = extractEmbeddedEcho(bytes) else { return .other(type: type, code: code) }
            return .destinationUnreachable(identifier: id, sequence: seq, code: code)

        default:
            return .other(type: type, code: code)
        }
    }

    /// bytes[8...] is the original (expired) IPv4 header, followed by the
    /// first 8 bytes of the original ICMP echo request we sent.
    private static func extractEmbeddedEcho(_ bytes: [UInt8]) -> (UInt16, UInt16)? {
        guard bytes.count >= 8 + 20 + 8 else { return nil }
        let ihl = Int(bytes[8] & 0x0F) * 4
        let echoStart = 8 + max(ihl, 20)
        guard bytes.count >= echoStart + 8 else { return nil }
        let identifier = UInt16(bytes[echoStart + 4]) << 8 | UInt16(bytes[echoStart + 5])
        let sequence = UInt16(bytes[echoStart + 6]) << 8 | UInt16(bytes[echoStart + 7])
        return (identifier, sequence)
    }
}
