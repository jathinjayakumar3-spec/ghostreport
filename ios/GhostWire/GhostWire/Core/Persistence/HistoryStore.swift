import Foundation
import Combine

/// Lightweight on-disk history/log store. Deliberately plain Codable + JSON
/// files (not SwiftData/CoreData) so the whole persistence layer is a
/// dependency-free, easily-auditable ~150 lines — appropriate for a
/// diagnostics tool whose data is thousands of small records, not megabytes.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var log: [DiagnosticsLogEntry] = []
    @Published private(set) var speedTestHistory: [SpeedTestResult] = []

    private let maxLogEntries = 1000
    private let maxSpeedRecords = 500

    private let logURL: URL
    private let speedURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        logURL = dir.appendingPathComponent("ghostwire_log.json")
        speedURL = dir.appendingPathComponent("ghostwire_speedtests.json")
        log = Self.load([DiagnosticsLogEntry].self, from: logURL) ?? []
        speedTestHistory = Self.load([SpeedTestResult].self, from: speedURL) ?? []
    }

    // MARK: Logging

    func record(_ severity: LogSeverity, category: String, _ message: String) {
        let entry = DiagnosticsLogEntry(timestamp: Date(), severity: severity, category: category, message: message)
        log.append(entry)
        if log.count > maxLogEntries {
            log.removeFirst(log.count - maxLogEntries)
        }
        persist(log, to: logURL)
    }

    func clearLog() {
        log.removeAll()
        persist(log, to: logURL)
    }

    func exportLogText() -> String {
        let fmt = ISO8601DateFormatter()
        return log.map { "[\(fmt.string(from: $0.timestamp))] \($0.severity.rawValue.uppercased()) · \($0.category) — \($0.message)" }
            .joined(separator: "\n")
    }

    // MARK: Speed test history

    func addSpeedTestResult(_ result: SpeedTestResult) {
        speedTestHistory.append(result)
        if speedTestHistory.count > maxSpeedRecords {
            speedTestHistory.removeFirst(speedTestHistory.count - maxSpeedRecords)
        }
        persist(speedTestHistory, to: speedURL)
    }

    func clearSpeedHistory() {
        speedTestHistory.removeAll()
        persist(speedTestHistory, to: speedURL)
    }

    func exportSpeedHistoryCSV() -> String {
        var lines = ["timestamp,download_mbps,upload_mbps,ping_ms,jitter_ms,loss_pct,server"]
        let fmt = ISO8601DateFormatter()
        for r in speedTestHistory {
            lines.append("\(fmt.string(from: r.timestamp)),\(r.downloadMbps),\(r.uploadMbps),\(r.pingMs),\(r.jitterMs),\(r.packetLossPct),\(r.server)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Codable helpers (SpeedTestResult needs Codable conformance below)

    private func persist<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try JSONEncoder.iso8601.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            // Persistence failures are non-fatal for a diagnostics app; surface in console only.
            print("HistoryStore persist error: \(error)")
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.iso8601.decode(T.self, from: data)
    }
}

extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension SpeedTestResult: Codable {
    enum CodingKeys: String, CodingKey {
        case pingMs, jitterMs, packetLossPct, downloadMbps, uploadMbps, server, timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        pingMs = try c.decode(Double.self, forKey: .pingMs)
        jitterMs = try c.decode(Double.self, forKey: .jitterMs)
        packetLossPct = try c.decode(Double.self, forKey: .packetLossPct)
        downloadMbps = try c.decode(Double.self, forKey: .downloadMbps)
        uploadMbps = try c.decode(Double.self, forKey: .uploadMbps)
        server = try c.decode(String.self, forKey: .server)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        phase = .done
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pingMs, forKey: .pingMs)
        try c.encode(jitterMs, forKey: .jitterMs)
        try c.encode(packetLossPct, forKey: .packetLossPct)
        try c.encode(downloadMbps, forKey: .downloadMbps)
        try c.encode(uploadMbps, forKey: .uploadMbps)
        try c.encode(server, forKey: .server)
        try c.encode(timestamp, forKey: .timestamp)
    }
}
