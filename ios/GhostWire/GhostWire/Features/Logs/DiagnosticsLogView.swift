import SwiftUI

struct DiagnosticsLogView: View {
    @ObservedObject private var store = HistoryStore.shared
    @State private var shareText: String?

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 0) {
                header
                if store.log.isEmpty {
                    emptyState
                } else {
                    logList
                }
            }
        }
        .navigationTitle("Diagnostics Log")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { shareText.map { ShareText(text: $0) } },
            set: { shareText = $0?.text }
        )) { item in
            ActivityView(activityItems: [item.text])
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("\(store.log.count) events")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.muted)
            Spacer()
            Button {
                shareText = store.exportLogText()
            } label: {
                Image(systemName: "square.and.arrow.up").foregroundStyle(Theme.cyan)
            }
            Button(role: .destructive) {
                store.clearLog()
            } label: {
                Image(systemName: "trash").foregroundStyle(Theme.rose)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 34))
                .foregroundStyle(Theme.faint)
            Text("Every ping, trace, lookup and path change GhostWire runs gets logged here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Spacer()
        }
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(store.log.reversed()) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(color(for: entry.severity)).frame(width: 7, height: 7).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.category)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(color(for: entry.severity))
                                Spacer()
                                Text(Formatters.timestamp(entry.timestamp))
                                    .font(Theme.mono(10.5))
                                    .foregroundStyle(Theme.faint)
                            }
                            Text(entry.message)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.ink2)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassCard()
                }
            }
            .padding(18)
            .padding(.bottom, 40)
        }
    }

    private func color(for severity: LogSeverity) -> Color {
        switch severity {
        case .info: return Theme.cyan
        case .warn: return Theme.amber
        case .error: return Theme.rose
        case .success: return Theme.green
        }
    }
}

private struct ShareText: Identifiable {
    let text: String
    var id: String { text }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
