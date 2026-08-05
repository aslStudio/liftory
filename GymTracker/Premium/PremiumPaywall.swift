import StoreKit
import SwiftUI

struct PremiumPaywall: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var premiumStore: PremiumStore

    private static let privacyPolicyURL = URL(string: "https://speckle-pair-5c3.notion.site/Liftory-Privacy-3a7133b8dd5a8042a5cef3f17cf1310a?pvs=74")!
    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    @State private var selectedProductID: String?

    private var selectedProduct: Product? {
        selectedProductID.flatMap { premiumStore.product(with: $0) } ?? premiumStore.defaultProduct
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    productsSection
                    benefitsSection
                }
                .padding()
            }
            .scrollContentBackground(.hidden)

            purchaseBar
        }
        .appGlassBackground()
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Restore") {
                    Task {
                        await premiumStore.restorePurchases()
                    }
                }
            }
        }
        .task {
            await premiumStore.refresh()
            selectedProductID = premiumStore.defaultProduct?.id
        }
        .onChange(of: premiumStore.isPremium) { _, isPremium in
            if isPremium {
                dismiss()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text("Liftory Premium")
                .font(.largeTitle.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Unlock full progress tracking, unlimited workout plans, and iCloud sync.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .liquidPanel()
    }

    private var productsSection: some View {
        VStack(spacing: 10) {
            if premiumStore.isLoadingProducts && premiumStore.products.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .liquidPanel()
            } else if premiumStore.products.isEmpty {
                ContentUnavailableView(
                    "Subscriptions Unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Check your connection and try again.")
                )
                .liquidPanel()
            } else {
                ForEach(premiumStore.products, id: \.id) { product in
                    Button {
                        selectedProductID = product.id
                    } label: {
                        PremiumProductCard(
                            product: product,
                            monthlyPrice: premiumStore.monthlyPriceText(for: product),
                            savings: premiumStore.savingsText(for: product),
                            isSelected: selectedProduct?.id == product.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let purchaseError = premiumStore.purchaseError {
                Text(purchaseError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Included", systemImage: "sparkles")
                .font(.headline)

            premiumBenefit("Full statistics dashboard", systemImage: "chart.xyaxis.line")
            premiumBenefit("Statistics inside workout and exercise details", systemImage: "chart.bar.xaxis")
            premiumBenefit("Unlimited workouts", systemImage: "figure.strengthtraining.traditional")
            premiumBenefit("iCloud sync across your devices", systemImage: "icloud.fill")
        }
        .liquidPanel()
    }

    private var purchaseBar: some View {
        VStack(spacing: 10) {
            Button {
                guard let selectedProduct else {
                    return
                }

                Task {
                    await premiumStore.purchase(selectedProduct)
                }
            } label: {
                Text(selectedProduct.map { "Continue - \($0.displayPrice)" } ?? "Continue")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.glassProminent)
            .disabled(selectedProduct == nil)

            Text("Subscriptions renew automatically until cancelled.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Link("Terms of Use", destination: Self.termsOfUseURL)
                Text("•")
                    .foregroundStyle(.secondary)
                Link("Privacy Policy", destination: Self.privacyPolicyURL)
            }
            .font(.caption2.weight(.semibold))
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func premiumBenefit(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PremiumProductCard: View {
    let product: Product
    let monthlyPrice: String?
    let savings: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(product.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let savings {
                        Text(savings)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.14))
                            }
                    }
                }

                if let monthlyPrice {
                    Text("\(monthlyPrice) / month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(product.displayPrice)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.8) : .white.opacity(0.18), lineWidth: 1.5)
                }
        }
    }
}

struct PremiumRequiredState: View {
    let title: String
    let message: String
    var systemImage: String = "crown.fill"

    @State private var isPaywallPresented = false

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(message)
            )

            Button {
                isPaywallPresented = true
            } label: {
                Label("Get Premium", systemImage: "crown.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.glassProminent)
        }
        .liquidPanel()
        .sheet(isPresented: $isPaywallPresented) {
            NavigationStack {
                PremiumPaywall()
            }
        }
    }
}
