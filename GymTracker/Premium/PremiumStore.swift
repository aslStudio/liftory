import Foundation
import Combine
import StoreKit

@MainActor
final class PremiumStore: ObservableObject {
    static let productIDs = [
        "liftory.premium.1month",
        "liftory.premium.3month",
        "liftory.premium.6month",
        "liftory.premium.12month"
    ]

    private static let premiumDefaultsKey = "liftory.isPremium"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published var purchaseError: String?

    private var updatesTask: Task<Void, Never>?

    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }

    var defaultProduct: Product? {
        product(with: "liftory.premium.12month") ?? products.first
    }

    static var cachedIsPremium: Bool {
        UserDefaults.standard.bool(forKey: premiumDefaultsKey)
    }

    init() {
        updatesTask = listenForTransactionUpdates()

        Task {
            await refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        await loadProducts()
        await updatePurchasedProducts()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { lhs, rhs in
                subscriptionMonths(for: lhs.id, default: Int.max) < subscriptionMonths(for: rhs.id, default: Int.max)
            }
            purchaseError = nil
        } catch {
            purchaseError = "Unable to load subscriptions. Please try again."
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)
                await transaction.finish()
                await updatePurchasedProducts()
                purchaseError = nil
            case .pending:
                purchaseError = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            purchaseError = nil
        } catch {
            purchaseError = "Unable to restore purchases."
        }
    }

    func product(with id: String) -> Product? {
        products.first { $0.id == id }
    }

    func monthlyPriceText(for product: Product) -> String? {
        guard let months = subscriptionMonths(for: product.id), months > 1 else {
            return nil
        }

        let monthlyPrice = product.price / Decimal(months)
        return monthlyPrice.formatted(product.priceFormatStyle)
    }

    func savingsText(for storeProduct: Product) -> String? {
        guard let monthlyProduct = product(with: "liftory.premium.1month"),
              let months = subscriptionMonths(for: storeProduct.id),
              months > 1 else {
            return nil
        }

        let fullPrice = monthlyProduct.price * Decimal(months)
        guard fullPrice > storeProduct.price else {
            return nil
        }

        let discount = (fullPrice - storeProduct.price) / fullPrice
        let percent = NSDecimalNumber(decimal: discount * 100).intValue
        return "Save \(percent)%"
    }

    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }

            if let expirationDate = transaction.expirationDate,
               expirationDate < Date() {
                continue
            }

            purchasedIDs.insert(transaction.productID)
        }

        purchasedProductIDs = purchasedIDs
        UserDefaults.standard.set(!purchasedIDs.isEmpty, forKey: Self.premiumDefaultsKey)
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                guard let transaction = try? checkVerified(result) else {
                    continue
                }

                await transaction.finish()
                await updatePurchasedProducts()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    private func subscriptionMonths(for productID: String) -> Int? {
        switch productID {
        case "liftory.premium.1month":
            return 1
        case "liftory.premium.3month":
            return 3
        case "liftory.premium.6month":
            return 6
        case "liftory.premium.12month":
            return 12
        default:
            return nil
        }
    }

    private func subscriptionMonths(for productID: String, default defaultValue: Int) -> Int {
        subscriptionMonths(for: productID) ?? defaultValue
    }
}

private enum StoreError: Error {
    case failedVerification
}
