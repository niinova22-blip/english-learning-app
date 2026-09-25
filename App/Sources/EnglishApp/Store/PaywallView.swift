import SwiftUI
import SwiftData
import LearningEngine

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
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
                    Button("Close") { dismiss() }.foregroundStyle(Theme.secondaryInk).accessibilityIdentifier("paywall-close")
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
        .sensoryFeedback(.success, trigger: viewModel?.state == .succeeded)
    }

    @ViewBuilder
    private func content(_ vm: PaywallViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            switch mode {
            case .premium: PremiumPitch()
            case .package(let productID, let packageName): PackagePitch(name: packageName, stats: packageStats(productID))
            }

            if vm.isAlreadyOwned {
                Text("This purchase is already active on your account.")
                    .font(.subheadline).foregroundStyle(Theme.primary)
            } else {
                purchaseSection(vm)
            }
        }
    }

    private func packageStats(_ productID: String) -> PackageStats? {
        let id: String? = productID
        let package = try? context.fetch(FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.storeProductID == id })).first
        return package.map(PackageStats.init)
    }

    @ViewBuilder
    private func purchaseSection(_ vm: PaywallViewModel) -> some View {
        switch vm.state {
        case .loadingProducts:
            ProgressView("Loading prices...").frame(maxWidth: .infinity)
        case .loadFailed:
            VStack(spacing: 10) {
                Text("Could not load prices.").foregroundStyle(Theme.secondaryInk)
                Button("Try again") { Task { await vm.load() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .pending:
            Text("Waiting for approval. It will unlock automatically once the purchase is approved.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
        case .ready, .purchasing, .succeeded, .failed:
            readyControls(vm)
        }
    }

    @ViewBuilder
    private func readyControls(_ vm: PaywallViewModel) -> some View {
        let isBusy = vm.state == .purchasing
        VStack(alignment: .leading, spacing: 14) {
            if mode == .premium {
                ForEach(vm.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: vm.selectedProductID == product.id,
                        savingsPercent: product.kind == .premiumYearly ? vm.savingsPercent : nil,
                        perMonth: vm.perMonthText(for: product)
                    ) { vm.selectedProductID = product.id }
                }
                if vm.showsTrialTimeline, let days = vm.selectedProduct?.trialDays {
                    TrialTimeline(trialDays: days)
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
                if isBusy { ProgressView().tint(.white) } else { Text(vm.ctaTitle) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isBusy || vm.selectedProduct == nil)

            if let terms = vm.trialTerms {
                Text(terms).font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }

            Button("Restore purchases") { Task { await vm.restore() } }
                .font(.subheadline).foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .disabled(isBusy)

            if mode == .premium { disclosure }
        }
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The subscription renews automatically unless cancelled at least 24 hours before the end of the period. Payment is charged to your Apple ID account at confirmation of purchase. You can manage and cancel the subscription from Settings > Apple ID > Subscriptions.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
            HStack(spacing: 16) {
                if let terms = StoreLinks.termsOfUse { Link("Terms of use", destination: terms) }
                if let privacy = StoreLinks.privacyPolicy { Link("Privacy policy", destination: privacy) }
            }
            .font(.caption)
        }
    }
}

/// Everything AI Premium does — only features the app actually ships.
private struct PremiumPitch: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Your personal coach and tutor, right on your phone")
                    .font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
                Label("Runs entirely on your device: works offline, and nothing you ask leaves your phone.", systemImage: "lock.shield.fill")
                    .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }

            FeatureSection(icon: "calendar.badge.checkmark", title: String(localized: "Study coach"), lines: [
                String(localized: "A daily plan built around your exam or target date"),
                String(localized: "Falls behind? It adds catch-up lessons to get you back on track"),
                String(localized: "Final week: switches to review only, no new material"),
                String(localized: "Focuses on the skill you need most"),
                String(localized: "Weekly summary and your estimated finish date"),
                String(localized: "A personal note from your coach"),
            ])
            FeatureSection(icon: "text.book.closed.fill", title: String(localized: "Word tutor"), lines: [
                String(localized: "\"Explain it more simply\" on any word card"),
                String(localized: "Fresh example sentences on demand"),
                String(localized: "How it differs from similar words"),
                String(localized: "Ask anything about the word"),
            ])
            FeatureSection(icon: "questionmark.bubble.fill", title: String(localized: "Question explainer"), lines: [
                String(localized: "Why your answer was wrong"),
                String(localized: "Why each of the other options doesn't fit"),
            ])
            FeatureSection(icon: "bubble.left.and.bubble.right.fill", title: String(localized: "Free chat"), lines: [
                String(localized: "Ask anything about English, in your language"),
            ])
        }
    }
}

private struct FeatureSection: View {
    let icon: String
    let title: String
    let lines: [String]

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.headline).foregroundStyle(Theme.primary)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Theme.primary)
                            .padding(.top, 3)
                        Text(line).font(.subheadline).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct PackagePitch: View {
    let name: String
    let stats: PackageStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(name).font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
            if let stats {
                HStack(spacing: 8) {
                    StatTile(value: "\(stats.units)", label: String(localized: "units"))
                    StatTile(value: "\(stats.lessons)", label: String(localized: "lessons"))
                    StatTile(value: "\(stats.questions)", label: String(localized: "questions"), tint: Theme.primary)
                }
            }
            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach([
                        String(localized: "Unlocks all units and lessons in the package"),
                        String(localized: "Vocabulary, grammar and reading practice"),
                        String(localized: "The first unit stays free, so you can try before you buy"),
                        String(localized: "One-time payment, no subscription"),
                    ], id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                            Text(line).font(.subheadline).foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
        }
    }
}

private struct PlanCard: View {
    let product: StoreProduct
    let isSelected: Bool
    let savingsPercent: Int?
    let perMonth: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(isSelected ? Theme.primary : Theme.secondaryInk)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.kind == .premiumYearly ? String(localized: "Yearly") : String(localized: "Monthly"))
                            .font(.headline).foregroundStyle(Theme.ink)
                        if let savingsPercent {
                            Text("Best value · save \(savingsPercent)%")
                                .font(.caption.weight(.bold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.accent, in: Capsule())
                        }
                    }
                    if let perMonth {
                        Text(perMonth).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }
                Spacer(minLength: 0)
                Text(product.displayPrice).font(.number(.headline)).foregroundStyle(Theme.ink)
            }
            .padding()
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.primary, lineWidth: isSelected ? 2 : 0))
            .cardShadow()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Today → reminder the day before → first charge.
private struct TrialTimeline: View {
    let trialDays: Int

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                step(icon: "lock.open.fill", title: String(localized: "Today"), detail: String(localized: "Full access to your coach and tutor."))
                step(icon: "bell.fill", title: String(localized: "Day \(max(trialDays - 1, 1))"), detail: String(localized: "We remind you that your trial ends tomorrow."))
                step(icon: "creditcard.fill", title: String(localized: "Day \(trialDays)"), detail: String(localized: "Your subscription starts. Cancel before then and you pay nothing."))
            }
        }
    }

    private func step(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(Theme.secondaryInk)
            }
        }
    }
}
