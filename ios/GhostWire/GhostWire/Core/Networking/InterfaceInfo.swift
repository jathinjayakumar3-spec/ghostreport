import Foundation

/// Enumerates local network interfaces via BSD `getifaddrs` — the same
/// public POSIX API `ifconfig` itself uses. No entitlement required.
enum InterfaceInfo {

    static func classify(_ bsdName: String) -> ConnectionKind {
        if bsdName == "lo0" { return .loopback }
        if bsdName.hasPrefix("en") { return .wifi }         // en0 is Wi-Fi on iOS devices
        if bsdName.hasPrefix("pdp_ip") || bsdName.hasPrefix("cellular") { return .cellular }
        if bsdName.hasPrefix("utun") || bsdName.hasPrefix("ppp") || bsdName.hasPrefix("ipsec") { return .vpn }
        if bsdName.hasPrefix("bridge") || bsdName.hasPrefix("ap") { return .wiredEthernet }
        return .unknown
    }

    /// Returns one merged record per active BSD interface with whatever
    /// IPv4/IPv6 addresses it carries.
    static func currentInterfaces() -> [NetworkInterfaceInfo] {
        var result: [String: NetworkInterfaceInfo] = [:]

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return [] }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ptr = cursor {
            defer { cursor = ptr.pointee.ifa_next }
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            guard let name = ptr.pointee.ifa_name else { continue }
            let bsdName = String(cString: name)
            guard bsdName != "lo0" else { continue } // hide loopback from the UI

            guard let addr = ptr.pointee.ifa_addr else { continue }
            let family = addr.pointee.sa_family

            var record = result[bsdName] ?? NetworkInterfaceInfo(
                name: bsdName, kind: classify(bsdName), ipv4: nil, ipv6: nil, netmask: nil,
                isActive: isUp && isRunning
            )
            record.isActive = record.isActive || (isUp && isRunning)

            if family == UInt8(AF_INET) {
                if let ip = sockaddrToString(addr) { record.ipv4 = ip }
                if let mask = ptr.pointee.ifa_netmask, let m = sockaddrToString(mask) { record.netmask = m }
            } else if family == UInt8(AF_INET6) {
                if record.ipv6 == nil, let ip = sockaddrToString(addr) { record.ipv6 = ip }
            }
            result[bsdName] = record
        }

        return result.values
            .filter { $0.ipv4 != nil || $0.ipv6 != nil }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
                return lhs.name < rhs.name
            }
    }

    /// The interface GhostWire treats as "primary" for the dashboard hero card.
    static func primaryInterface(from list: [NetworkInterfaceInfo]) -> NetworkInterfaceInfo? {
        list.first { $0.isActive && $0.kind == .wifi }
            ?? list.first { $0.isActive && $0.kind == .cellular }
            ?? list.first { $0.isActive && $0.kind == .wiredEthernet }
            ?? list.first { $0.isActive }
    }

    /// Cumulative rx/tx byte counters for a BSD interface, read from
    /// `ifa_data` (an `if_data` struct) — the same counters `netstat -i`
    /// reads. Callers diff two samples over a known time delta to derive an
    /// actual, measured throughput number (not an estimate). Returns `nil`
    /// if the OS doesn't hand back interface stats in this context, which
    /// callers must handle gracefully rather than showing a fabricated value.
    static func byteCounters(for bsdName: String) -> (rx: UInt64, tx: UInt64)? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            defer { cursor = ptr.pointee.ifa_next }
            guard let name = ptr.pointee.ifa_name, String(cString: name) == bsdName else { continue }
            guard let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            guard let dataPtr = ptr.pointee.ifa_data else { continue }
            let ifData = dataPtr.assumingMemoryBound(to: if_data.self).pointee
            return (UInt64(ifData.ifi_ibytes), UInt64(ifData.ifi_obytes))
        }
        return nil
    }

    private static func sockaddrToString(_ sa: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
        guard result == 0 else { return nil }
        var ip = String(cString: host)
        // Strip IPv6 zone-id suffix (e.g. "%en0") which is noisy in the UI.
        if let pct = ip.firstIndex(of: "%") { ip = String(ip[ip.startIndex..<pct]) }
        return ip
    }
}
