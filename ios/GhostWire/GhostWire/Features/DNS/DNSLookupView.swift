import SwiftUI

struct DNSLookupView: View {
    @StateObject private var vm = DNSLookupViewModel()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(spacing: 18) {
                    queryCard
                    typePicker
                    GlassButton(title: "Lookup", icon: "magnifyingglass", prominent: true, isLoading: vm.isRunning) {
                        fieldFocused = false
                        vm.run()
                    }
                    if let summary = vm.summary {
                        resultsCard(summary)
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("DNS Lookup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var queryCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack").foregroundStyle(Theme.muted)
            TextField("Domain name", text: $vm.queryName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($fieldFocused)
                .font(Theme.mono(15))
                .foregroundStyle(Theme.ink)
                .onSubmit { vm.run() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard()
    }

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DNSRecordType.allCases) { type in
                    Button {
                        vm.selectedType = type
                    } label: {
                        Text(type.rawValue)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(vm.selectedType == type ? Theme.bgTop : Theme.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if vm.selectedType == type {
                                    Capsule().fill(Theme.signalGradient)
                                } else {
                                    Capsule().fill(.ultraThinMaterial)
                                        .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
                                }
                            }
                    }
                }
            }
        }
    }

    private func resultsCard(_ summary: DNSLookupSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "\(summary.records.count) record(s)", subtitle: String(format: "%.0f ms", summary.durationMs))
            }
            if let error = summary.errorMessage, summary.records.isEmpty {
                Text(error)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.amber)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.records.enumerated()), id: \.element.id) { i, record in
                        if i > 0 { Divider().overlay(Theme.glassStroke) }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.type.rawValue)
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(Theme.cyan)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Capsule().fill(Theme.cyan.opacity(0.15)))
                                Text(record.name)
                                    .font(Theme.mono(11.5))
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                Text("TTL \(record.ttl)s")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.faint)
                            }
                            Text(record.value)
                                .font(Theme.mono(13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 14)
                .glassCard()
            }
        }
    }
}
