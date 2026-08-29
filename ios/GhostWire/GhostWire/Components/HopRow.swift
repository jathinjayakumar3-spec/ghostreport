import SwiftUI

struct HopRow: View {
    let hop: TraceHop

    private var rttColor: Color {
        guard let ms = hop.averageMs else { return Theme.faint }
        if ms < 30 { return Theme.green }
        if ms < 100 { return Theme.amber }
        return Theme.rose
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(hop.timedOut ? Theme.faint.opacity(0.2) : rttColor.opacity(0.18))
                    .frame(width: 30, height: 30)
                Text("\(hop.ttl)")
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(hop.timedOut ? Theme.faint : rttColor)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(hop.host ?? (hop.timedOut ? "Request timed out" : "—"))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let ip = hop.ipAddress {
                    Text(ip)
                        .font(Theme.mono(11.5))
                        .foregroundStyle(Theme.muted)
                }
                if !hop.timedOut {
                    HStack(spacing: 10) {
                        ForEach(Array(hop.samplesMs.enumerated()), id: \.offset) { _, ms in
                            Text(ms.map { String(format: "%.0fms", $0) } ?? "*")
                                .font(Theme.mono(10.5))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                }
            }

            Spacer()

            if let ms = hop.averageMs {
                Text(String(format: "%.0f ms", ms))
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(rttColor)
            }
        }
        .padding(.vertical, 6)
    }
}
