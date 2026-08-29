import Foundation
import Darwin
import dnssd

/// `dig`-style DNS resolver built on Apple's public `dnssd` (Bonjour/
/// mDNSResponder) C API — `DNSServiceQueryRecord` — which is able to query
/// any RR type against the system's configured (usually DHCP-assigned)
/// resolver, unlike `getaddrinfo` which only ever gives you A/AAAA.
enum DNSResolver {

    /// Runs one query for `name`/`type` and returns whatever records came
    /// back within `timeout` seconds.
    static func query(name: String, type: DNSRecordType, timeout: TimeInterval = 4) async -> DNSLookupSummary {
        let started = Date()
        var summary = DNSLookupSummary()
        summary.queryName = name

        let records = await withCheckedContinuation { (continuation: CheckedContinuation<[DNSRecordResult], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runQuery(name: name, type: type, timeout: timeout))
            }
        }

        summary.records = records
        summary.durationMs = Date().timeIntervalSince(started) * 1000

        if records.isEmpty {
            summary.errorMessage = "No \(type.rawValue) records found (or the resolver did not answer in time)."
        }

        await HistoryStore.shared.record(
            records.isEmpty ? .warn : .success,
            category: "DNS",
            "\(type.rawValue) \(name) → \(records.count) record(s) in \(String(format: "%.0f", summary.durationMs))ms"
        )

        return summary
    }

    // MARK: - Blocking implementation (runs on a background queue)

    private static func runQuery(name: String, type: DNSRecordType, timeout: TimeInterval) -> [DNSRecordResult] {
        let box = DNSQueryBox()
        let boxPtr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<DNSQueryBox>.fromOpaque(boxPtr).release() }

        var sdRef: DNSServiceRef?
        let err = name.withCString { cName -> DNSServiceErrorType in
            DNSServiceQueryRecord(&sdRef, 0, 0, cName, type.code, 1 /* kDNSServiceClass_IN */, dnsResolverCallback, boxPtr)
        }
        guard err == kDNSServiceErr_NoError, let ref = sdRef else { return [] }
        defer { DNSServiceRefDeallocate(ref) }

        let fd = DNSServiceRefSockFD(ref)
        guard fd >= 0 else { return [] }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&pfd, 1, 300)
            if ready > 0 && (Int32(pfd.revents) & POLLIN) != 0 {
                let processErr = DNSServiceProcessResult(ref)
                guard processErr == kDNSServiceErr_NoError else { break }
                if !box.moreComing && !box.records.isEmpty { break }
            } else if !box.records.isEmpty {
                break // quiet period after receiving at least one answer
            }
        }
        return box.records
    }

    // MARK: - RDATA decoding

    static func decode(type: DNSRecordType, bytes: [UInt8]) -> String? {
        switch type {
        case .a:
            guard bytes.count == 4 else { return nil }
            return bytes.map(String.init).joined(separator: ".")

        case .aaaa:
            guard bytes.count == 16 else { return nil }
            var addr = in6_addr()
            withUnsafeMutableBytes(of: &addr) { dst in
                dst.copyBytes(from: bytes)
            }
            var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            inet_ntop(AF_INET6, &addr, &buf, socklen_t(INET6_ADDRSTRLEN))
            return String(cString: buf)

        case .cname, .ns, .ptr:
            return decodeName(bytes, from: 0)?.0

        case .mx:
            guard bytes.count > 2 else { return nil }
            let pref = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            guard let (name, _) = decodeName(bytes, from: 2) else { return "\(pref) ?" }
            return "\(pref) \(name)"

        case .srv:
            guard bytes.count > 6 else { return nil }
            let priority = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            let weight = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
            let port = (UInt16(bytes[4]) << 8) | UInt16(bytes[5])
            let target = decodeName(bytes, from: 6)?.0 ?? "?"
            return "\(priority) \(weight) \(port) \(target)"

        case .txt:
            var strings: [String] = []
            var i = 0
            while i < bytes.count {
                let len = Int(bytes[i]); i += 1
                guard i + len <= bytes.count else { break }
                strings.append("\"" + (String(decoding: bytes[i..<(i + len)], as: UTF8.self)) + "\"")
                i += len
            }
            return strings.isEmpty ? nil : strings.joined(separator: " ")

        case .soa:
            guard let (mname, off1) = decodeName(bytes, from: 0),
                  let (rname, off2) = decodeName(bytes, from: off1),
                  bytes.count >= off2 + 20 else { return nil }
            let vals = stride(from: off2, to: off2 + 20, by: 4).map { o -> UInt32 in
                (UInt32(bytes[o]) << 24) | (UInt32(bytes[o+1]) << 16) | (UInt32(bytes[o+2]) << 8) | UInt32(bytes[o+3])
            }
            return "\(mname) \(rname) serial=\(vals[0]) refresh=\(vals[1]) retry=\(vals[2]) expire=\(vals[3]) min=\(vals[4])"

        case .caa:
            guard bytes.count > 2 else { return nil }
            let tagLen = Int(bytes[1])
            guard bytes.count >= 2 + tagLen else { return nil }
            let flags = bytes[0]
            let tag = String(decoding: bytes[2..<(2 + tagLen)], as: UTF8.self)
            let value = String(decoding: bytes[(2 + tagLen)...], as: UTF8.self)
            return "\(flags) \(tag) \"\(value)\""
        }
    }

    /// Decodes an uncompressed DNS name (length-prefixed labels, zero
    /// terminated) starting at `offset`. Returns `nil` if it hits a
    /// compression pointer (0xC0 top bits) — mDNSResponder occasionally
    /// leaves these in place, and correctly resolving them would require the
    /// full original packet, which the dnssd API doesn't hand back to us.
    private static func decodeName(_ bytes: [UInt8], from offset: Int) -> (String, Int)? {
        var labels: [String] = []
        var i = offset
        while i < bytes.count {
            let len = Int(bytes[i])
            if len == 0 { i += 1; break }
            if (len & 0xC0) == 0xC0 { return nil }
            i += 1
            guard i + len <= bytes.count else { return nil }
            labels.append(String(decoding: bytes[i..<(i + len)], as: UTF8.self))
            i += len
        }
        let name = labels.isEmpty ? "." : labels.joined(separator: ".") + "."
        return (name, i)
    }
}

/// Mutable box bridged through the C callback's `void *context`.
final class DNSQueryBox {
    var records: [DNSRecordResult] = []
    var moreComing: Bool = false
}

/// Non-capturing C function pointer required by `DNSServiceQueryRecord`.
private func dnsResolverCallback(
    sdRef: DNSServiceRef?,
    flags: DNSServiceFlags,
    interfaceIndex: UInt32,
    errorCode: DNSServiceErrorType,
    fullname: UnsafePointer<CChar>?,
    rrtype: UInt16,
    rrclass: UInt16,
    rdlen: UInt16,
    rdata: UnsafeRawPointer?,
    ttl: UInt32,
    context: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    let box = Unmanaged<DNSQueryBox>.fromOpaque(context).takeUnretainedValue()
    box.moreComing = (flags & DNSServiceFlags(kDNSServiceFlagsMoreComing)) != 0
    guard errorCode == kDNSServiceErr_NoError, let rdata, rdlen > 0, let fullname else { return }
    guard let type = DNSRecordType.allCases.first(where: { $0.code == rrtype }) else { return }

    let bytes = Array(UnsafeRawBufferPointer(start: rdata, count: Int(rdlen)))
    let value = DNSResolver.decode(type: type, bytes: bytes)
        ?? "0x" + bytes.map { String(format: "%02x", $0) }.joined()

    box.records.append(DNSRecordResult(type: type, name: String(cString: fullname), value: value, ttl: ttl))
}
