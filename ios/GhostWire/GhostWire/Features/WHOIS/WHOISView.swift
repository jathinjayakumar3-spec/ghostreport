import SwiftUI

struct WHOISView: View {
    @StateObject private var vm = WHOISViewModel()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass").foregroundStyle(Theme.muted)
                        TextField("Domain or IP", text: $vm.query)
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

                    GlassButton(title: "Lookup", icon: "magnifyingglass", prominent: true, isLoading: vm.isRunning) {
                        fieldFocused = false
                        vm.run()
                    }

                    if let result = vm.result {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Response", subtitle: "via \(result.server)")
                            if let error = result.errorMessage {
                                Text(error).font(.system(size: 12.5)).foregroundStyle(Theme.amber)
                            } else {
                                Text(result.raw)
                                    .font(Theme.mono(11.5))
                                    .foregroundStyle(Theme.ink2)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(16)
                        .glassCard(corner: Theme.r2)
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("WHOIS")
        .navigationBarTitleDisplayMode(.inline)
    }
}
