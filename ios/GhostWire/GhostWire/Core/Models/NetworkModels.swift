import Foundation

// MARK: - Connection / interface

enum ConnectionKind: String, Codable {
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case wiredEthernet = "Ethernet"
    case loopback = "Loopback"
    case vpn = "VPN"
    case unknown = "Unknown"

    var systemImage: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wiredEthernet: return "cable.connector"
        case .loopback: return "arrow.triangle.2.circlepath"
        case .vpn: return "lock.shield"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct NetworkInterfaceInfo: Identifiable, Equatable {
    var id: String { name }
    let name: String                 // e.g. "en0"
    let kind: ConnectionKind
    var ipv4: String?
    var ipv6: String?
    var netmask: String?
    var isActive: Bool
}

struct WiFiInfo: Equatable {
    var ssid: String?
    var bssid: String?
    var isSecure: Bool?
    var reachedViaEntitlement: Bool = true
}

struct GatewayInfo: Equatable {
    var routerIPv4: String?
    var dnsServers: [String] = []
}

struct PublicIPInfo: Equatable {
    var ip: String?
    var countryCode: String?
    var colo: String?          // Cloudflare edge datacenter (proxy for ISP routing path)
    var asnDescription: String?
    var isp: String?
}

/// Full snapshot the Dashboard / WLAN screens render from.
struct NetworkSnapshot: Equatable {
    var pathStatus: String = "Checking…"
    var isExpensive: Bool = false
    var isConstrained: Bool = false
    var primary: NetworkInterfaceInfo?
    var allInterfaces: [NetworkInterfaceInfo] = []
    var wifi: WiFiInfo = WiFiInfo()
    var gateway: GatewayInfo = GatewayInfo()
    var publicIP: PublicIPInfo = PublicIPInfo()
    var throughputDownKbps: Double = 0
    var throughputUpKbps: Double = 0
}

// MARK: - Ping

struct PingSample: Identifiable, Equatable {
    let id = UUID()
    let sequence: Int
    let rttMs: Double?     // nil = timeout / loss
    let ttl: Int?
    let timestamp: Date
}

struct PingSummary: Equatable {
    var host: String = ""
    var resolvedIP: String = ""
    var sent: Int = 0
    var received: Int = 0
    var minMs: Double = 0
    var avgMs: Double = 0
    var maxMs: Double = 0
    var jitterMs: Double = 0
    var packetLossPct: Double = 0

    var qualityScore: Double {
        guard sent > 0 else { return 0 }
        let lossPenalty = 1 - (packetLossPct / 100)
        let latencyScore = avgMs <= 0 ? 1 : max(0, 1 - (avgMs / 250))
        let jitterScore = max(0, 1 - (jitterMs / 100))
        return max(0, min(1, lossPenalty * 0.5 + latencyScore * 0.35 + jitterScore * 0.15))
    }
}

// MARK: - Traceroute

struct TraceHop: Identifiable, Equatable {
    let id = UUID()
    let ttl: Int
    var ipAddress: String?
    var host: String?
    var samplesMs: [Double?] = []
    var timedOut: Bool = false
    var isDestination: Bool = false

    var averageMs: Double? {
        let vals = samplesMs.compactMap { $0 }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }
}

// MARK: - DNS

enum DNSRecordType: String, CaseIterable, Identifiable {
    case a = "A", aaaa = "AAAA", cname = "CNAME", mx = "MX"
    case txt = "TXT", ns = "NS", soa = "SOA", srv = "SRV",
         ptr = "PTR", caa = "CAA"
    var id: String { rawValue }

    /// DNS wire-format numeric type, per RFC 1035 / RFC 6844.
    var code: UInt16 {
        switch self {
        case .a: return 1
        case .ns: return 2
        case .cname: return 5
        case .soa: return 6
        case .ptr: return 12
        case .mx: return 15
        case .txt: return 16
        case .aaaa: return 28
        case .srv: return 33
        case .caa: return 257
        }
    }
}

struct DNSRecordResult: Identifiable, Equatable {
    let id = UUID()
    let type: DNSRecordType
    let name: String
    let value: String
    let ttl: UInt32
}

struct DNSLookupSummary: Equatable {
    var queryName: String = ""
    var records: [DNSRecordResult] = []
    var durationMs: Double = 0
    var resolverUsed: String = "System"
    var errorMessage: String?
}

// MARK: - Speed test

enum SpeedTestPhase: String {
    case idle = "Idle", latency = "Measuring latency", download = "Testing download",
         upload = "Testing upload", done = "Complete", failed = "Failed"
}

struct SpeedTestResult: Equatable {
    var phase: SpeedTestPhase = .idle
    var pingMs: Double = 0
    var jitterMs: Double = 0
    var packetLossPct: Double = 0
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
    var server: String = "speed.cloudflare.com"
    var timestamp: Date = .init()
    var liveSamples: [Double] = []   // rolling instantaneous throughput for the gauge/sparkline
}

// MARK: - Port scan

struct PortDefinition {
    let port: Int
    let service: String
}

enum PortStatus: String { case open = "Open", closed = "Closed", filtered = "Filtered", scanning = "Scanning" }

struct PortScanResult: Identifiable, Equatable {
    let id = UUID()
    let port: Int
    let service: String
    var status: PortStatus
    var latencyMs: Double?
}

// MARK: - WHOIS

struct WHOISResult: Equatable {
    var query: String = ""
    var raw: String = ""
    var server: String = ""
    var errorMessage: String?
}

// MARK: - Diagnostics log

enum LogSeverity: String, Codable { case info, warn, error, success }

struct DiagnosticsLogEntry: Identifiable, Equatable, Codable {
    var id = UUID()
    let timestamp: Date
    let severity: LogSeverity
    let category: String
    let message: String
}
