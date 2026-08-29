import Foundation
import Network

/// TCP-connect port scanner built on `Network.framework`'s `NWConnection` —
/// no raw sockets, no entitlement, works over Wi-Fi or cellular. Scans run
/// with bounded concurrency so a full common-ports sweep stays fast without
/// hammering the target.
enum PortScanner {

    static let commonPorts: [PortDefinition] = [
        .init(port: 21, service: "FTP"), .init(port: 22, service: "SSH"),
        .init(port: 23, service: "Telnet"), .init(port: 25, service: "SMTP"),
        .init(port: 53, service: "DNS"), .init(port: 80, service: "HTTP"),
        .init(port: 110, service: "POP3"), .init(port: 111, service: "RPCbind"),
        .init(port: 123, service: "NTP"), .init(port: 135, service: "MS-RPC"),
        .init(port: 139, service: "NetBIOS"), .init(port: 143, service: "IMAP"),
        .init(port: 161, service: "SNMP"), .init(port: 389, service: "LDAP"),
        .init(port: 443, service: "HTTPS"), .init(port: 445, service: "SMB"),
        .init(port: 465, service: "SMTPS"), .init(port: 514, service: "Syslog"),
        .init(port: 587, service: "SMTP (sub)"), .init(port: 631, service: "IPP"),
        .init(port: 993, service: "IMAPS"), .init(port: 995, service: "POP3S"),
        .init(port: 1433, service: "MSSQL"), .init(port: 1723, service: "PPTP"),
        .init(port: 2049, service: "NFS"), .init(port: 3000, service: "Dev HTTP"),
        .init(port: 3306, service: "MySQL"), .init(port: 3389, service: "RDP"),
        .init(port: 5060, service: "SIP"), .init(port: 5432, service: "PostgreSQL"),
        .init(port: 5900, service: "VNC"), .init(port: 6379, service: "Redis"),
        .init(port: 8000, service: "HTTP-alt"), .init(port: 8080, service: "HTTP-proxy"),
        .init(port: 8443, service: "HTTPS-alt"), .init(port: 8883, service: "MQTT-TLS"),
        .init(port: 9000, service: "Dev HTTP"), .init(port: 9200, service: "Elasticsearch"),
        .init(port: 27017, service: "MongoDB"),
    ]

    static func scan(
        host: String,
        ports: [PortDefinition],
        timeout: TimeInterval = 2.5,
        maxConcurrent: Int = 24,
        onResult: @escaping @Sendable (PortScanResult) -> Void
    ) async {
        await HistoryStore.shared.record(.info, category: "Port Scan", "Scanning \(ports.count) ports on \(host)")
        var openCount = 0

        await withTaskGroup(of: PortScanResult.self) { group in
            var iterator = ports.makeIterator()
            var inFlight = 0

            func submitNext() {
                guard let def = iterator.next() else { return }
                inFlight += 1
                group.addTask {
                    await Self.probe(host: host, def: def, timeout: timeout)
                }
            }

            for _ in 0..<maxConcurrent { submitNext() }

            while let result = await group.next() {
                inFlight -= 1
                if result.status == .open { openCount += 1 }
                onResult(result)
                submitNext()
                _ = inFlight
            }
        }

        await HistoryStore.shared.record(.success, category: "Port Scan", "\(host): \(openCount)/\(ports.count) open")
    }

    private static func probe(host: String, def: PortDefinition, timeout: TimeInterval) async -> PortScanResult {
        await withCheckedContinuation { continuation in
            let start = Date()
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(def.port)) else {
                continuation.resume(returning: PortScanResult(port: def.port, service: def.service, status: .filtered, latencyMs: nil))
                return
            }

            let params = NWParameters.tcp
            params.prohibitExpensivePaths = false
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: params)

            var finished = false
            let lock = NSLock()
            func finish(_ status: PortStatus) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                connection.cancel()
                let latency = Date().timeIntervalSince(start) * 1000
                continuation.resume(returning: PortScanResult(port: def.port, service: def.service, status: status, latencyMs: status == .open ? latency : nil))
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(.open)
                case .failed, .cancelled: finish(.closed)
                default: break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(.filtered)
            }
        }
    }
}
