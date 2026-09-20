import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: PaywallMode
    let store: EntitlementStore
    @State private var viewModel: PaywallViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let viewModel {
                    content(viewModel).padding()
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }.foregroundStyle(Theme.secondaryInk)
                }
            }
        }
        .task {
            let vm = viewModel ?? PaywallViewModel(mode: mode, store: store)
            viewModel = vm
            await vm.load()
        }
        .onChange(of: viewModel?.state) { _, state in
            if state == .succeeded { dismiss() }
        }
    }

    @ViewBuilder
    private func content(_ vm: PaywallViewModel) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(vm.title).font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)

            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(benefits, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                            Text(line).font(.subheadline).foregroundStyle(Theme.ink)
                        }
                    }
                }
            }

            if vm.isAlreadyOwned {
                Text("Bu satın alım zaten hesabında açık.")
                    .font(.subheadline).foregroundStyle(Theme.primary)
            } else {
                purchaseSection(vm)
            }
        }
    }

    @ViewBuilder
    private func purchaseSection(_ vm: PaywallViewModel) -> some View {
        switch vm.state {
        case .loadingProducts:
            ProgressView("Fiyatlar yükleniyor...").frame(maxWidth: .infinity)
        case .loadFailed:
            VStack(spacing: 10) {
                Text("Fiyatlar yüklenemedi.").foregroundStyle(Theme.secondaryInk)
                Button("Tekrar dene") { Task { await vm.load() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .pending:
            Text("Onay bekleniyor. Satın alım onaylanınca otomatik açılacak.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
        case .ready, .purchasing, .succeeded, .failed:
            readyControls(vm)
        }
    }

    @ViewBuilder
    private func readyControls(_ vm: PaywallViewModel) -> some View {
        let isBusy = vm.state == .purchasing
        VStack(alignment: .leading, spacing: 12) {
            if mode == .premium {
                ForEach(vm.products, id: \.id) { product in
                    Button {
                        vm.selectedProductID = product.id
                    } label: {
                        HStack {
                            Text(product.displayName).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(product.displayPrice).foregroundStyle(Theme.primary)
                        }
                        .padding()
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(vm.selectedProductID == product.id ? Theme.primary : Theme.border, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if case .failed(let message) = vm.state {
                Text(message).font(.subheadline).foregroundStyle(Theme.danger)
            }
            if let notice = vm.notice {
                Text(notice).font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }

            Button {
                Task { await vm.purchase() }
            } label: {
                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Text(purchaseTitle(vm))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isBusy || vm.selectedProduct == nil)

            Button("Satın alımları geri yükle") { Task { await vm.restore() } }
                .font(.subheadline).foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .disabled(isBusy)

            if mode == .premium { disclosure }
        }
    }

    private func purchaseTitle(_ vm: PaywallViewModel) -> String {
        let price = vm.selectedProduct?.displayPrice ?? ""
        return mode == .premium ? "Abone ol · \(price)" : "Satın al · \(price)"
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Abonelik, dönem bitiminden en az 24 saat önce iptal edilmezse otomatik olarak yenilenir. Ödeme, satın alma onayında Apple ID hesabından alınır. Aboneliği Ayarlar > Apple ID > Abonelikler bölümünden yönetebilir ve iptal edebilirsin.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
            HStack(spacing: 16) {
                if let terms = StoreLinks.termsOfUse { Link("Kullanım şartları", destination: terms) }
                if let privacy = StoreLinks.privacyPolicy { Link("Gizlilik politikası", destination: privacy) }
            }
            .font(.caption)
        }
    }

    private var benefits: [String] {
        switch mode {
        case .package:
            return [
                "Paketin tüm üniteleri ve dersleri açılır",
                "Kelime, gramer ve okuma çalışmaları",
                "Tek seferlik ödeme, abonelik yok",
            ]
        case .premium:
            return [
                "Öğretmene Sor: sorunun cevabını Türkçe açıklar",
                "Öğretmenle serbest sohbet",
                "Çalışma koçu (yakında)",
                "İstediğin zaman iptal edebilirsin",
            ]
        }
    }
}
