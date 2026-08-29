import Foundation

/// Speed test against Cloudflare's public, key-free speed-test endpoints —
/// the same `speed.cloudflare.com` infrastructure the official 1.1.1.1 speed
/// test page itself uses, which sits on the same network as the 1.1.1.1
/// resolver. Latency/jitter/loss are measured with real ICMP echoes straight
/// to 1.1.1.1; download/upload are measured with time-bounded transfers so
/// results are comparable regardless of link speed.
actor SpeedTestEngine {

    struct Config {
        var latencyHost = "1.1.1.1"
        var latencyProbes = 12
        var downloadSeconds: TimeInterval = 8
        var uploadSeconds: TimeInterval = 6
        var downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=500000000")!
        var uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
        var uploadChunkBytes = 4 * 1024 * 1024
    }

    private let config: Config
    /// Actor-isolated so both the linear `run()` flow and the background
    /// throughput callbacks (bridged back in via `recordSample`) can safely
    /// touch it without racing.
    private var result = SpeedTestResult()

    init(config: Config = Config()) { self.config = config }

    /// Drives the full sequence, streaming progress via `onUpdate` and
    /// returning the final aggregated result.
    func run(onUpdate: @escaping @Sendable (SpeedTestResult) -> Void) async -> SpeedTestResult {
        result = SpeedTestResult()
        result.server = config.downloadURL.host ?? "speed.cloudflare.com"

        // 1) Latency / jitter / loss
        result.phase = .latency
        onUpdate(result)
        let pingSummary = await ICMPPing.run(host: config.latencyHost, count: config.latencyProbes, timeout: 1.5, interval: 0.15)
        result.pingMs = pingSummary.avgMs
        result.jitterMs = pingSummary.jitterMs
        result.packetLossPct = pingSummary.packetLossPct
        onUpdate(result)

        // 2) Download
        result.phase = .download
        result.liveSamples = []
        onUpdate(result)
        let downMbps = await Self.measureDownload(url: config.downloadURL, duration: config.downloadSeconds) { [weak self] instantMbps in
            guard let self else { return }
            Task { await self.recordSample(instantMbps, onUpdate: onUpdate) }
        }
        result.downloadMbps = downMbps
        onUpdate(result)

        // 3) Upload
        result.phase = .upload
        result.liveSamples = []
        onUpdate(result)
        let upMbps = await Self.measureUpload(url: config.uploadURL, duration: config.uploadSeconds, chunkBytes: config.uploadChunkBytes) { [weak self] instantMbps in
            guard let self else { return }
            Task { await self.recordSample(instantMbps, onUpdate: onUpdate) }
        }
        result.uploadMbps = upMbps
        result.phase = .done
        result.timestamp = Date()
        onUpdate(result)

        await HistoryStore.shared.record(
            .success, category: "Speed Test",
            "↓\(String(format: "%.1f", downMbps)) Mbps ↑\(String(format: "%.1f", upMbps)) Mbps · \(String(format: "%.0f", result.pingMs))ms ping"
        )
        await HistoryStore.shared.addSpeedTestResult(result)

        return result
    }

    /// Actor-isolated landing point for throughput samples that originate on
    /// background threads (URLSession delegate queue, upload loop) — keeps
    /// every mutation of `result` serialized through the actor.
    private func recordSample(_ instantMbps: Double, onUpdate: @escaping @Sendable (SpeedTestResult) -> Void) {
        result.liveSamples.append(instantMbps)
        if result.liveSamples.count > 60 { result.liveSamples.removeFirst() }
        onUpdate(result)
    }

    // MARK: Download — time-bounded streaming GET

    private static func measureDownload(
        url: URL, duration: TimeInterval, onSample: @escaping @Sendable (Double) -> Void
    ) async -> Double {
        let collector = ThroughputCollector(onSample: onSample)
        let session = URLSession(configuration: .ephemeral, delegate: collector, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.timeoutInterval = duration + 5
        let task = session.dataTask(with: request)
        let started = Date()
        task.resume()

        // Cancel at the time budget regardless of how much data arrived.
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        task.cancel()
        try? await Task.sleep(nanoseconds: 150_000_000) // let the last delegate callback land

        let elapsed = max(Date().timeIntervalSince(started), 0.05)
        let totalBits = Double(collector.totalBytes) * 8
        return (totalBits / elapsed) / 1_000_000
    }

    // MARK: Upload — sequential fixed-size chunks within the time budget

    private static func measureUpload(
        url: URL, duration: TimeInterval, chunkBytes: Int, onSample: @escaping @Sendable (Double) -> Void
    ) async -> Double {
        let payload = Data((0..<chunkBytes).map { _ in UInt8.random(in: 0...255) })
        let session = URLSession(configuration: .ephemeral)
        let deadline = Date().addingTimeInterval(duration)
        var totalBytes: Int64 = 0
        let started = Date()

        while Date() < deadline {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = payload
            request.timeoutInterval = 10
            let chunkStart = Date()
            do {
                _ = try await session.data(for: request)
                totalBytes += Int64(payload.count)
                let chunkElapsed = max(Date().timeIntervalSince(chunkStart), 0.01)
                let instantMbps = (Double(payload.count) * 8 / chunkElapsed) / 1_000_000
                onSample(instantMbps)
            } catch {
                break
            }
        }

        let elapsed = max(Date().timeIntervalSince(started), 0.05)
        let totalBits = Double(totalBytes) * 8
        return (totalBits / elapsed) / 1_000_000
    }
}

/// URLSession delegate that tallies bytes received and emits periodic
/// instantaneous-throughput samples for the live gauge. Runs on the
/// session's delegate queue (an arbitrary background thread) — its own
/// state is protected by a lock, and `onSample` is expected to hop back
/// onto whatever isolation domain actually owns the data it forwards to.
private final class ThroughputCollector: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private(set) var totalBytes: Int64 = 0
    private var windowBytes: Int64 = 0
    private var windowStart = Date()
    private let onSample: @Sendable (Double) -> Void
    private let lock = NSLock()

    init(onSample: @escaping @Sendable (Double) -> Void) {
        self.onSample = onSample
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        totalBytes += Int64(data.count)
        windowBytes += Int64(data.count)
        let now = Date()
        let windowElapsed = now.timeIntervalSince(windowStart)
        if windowElapsed >= 0.25 {
            let mbps = (Double(windowBytes) * 8 / windowElapsed) / 1_000_000
            windowBytes = 0
            windowStart = now
            lock.unlock()
            onSample(mbps)
            return
        }
        lock.unlock()
    }
}
