import Foundation
import Observation
import StoreKit

/// StoreKit 2 backing for a game's optional patronage purchase.
///
/// The purchase unlocks no gameplay. The game stays fully playable, free, and
/// ad-free; the entitlement exists only for supporter identity and cosmetics.
@MainActor
@Observable
public final class SupportStore {
    // App Store Connect rejects hyphens in product IDs, so this cannot mirror
    // the bundle ID (com.centaur-labs.est). It follows the same short scheme as
    // the Game Center IDs: "<product>.support", so "est.support".
    // Nil means the game ships without a support purchase; the store then
    // loads nothing and `isSupporter` stays false.
    public static var productID: String? { GameIdentity.current.supportProductID }

    public private(set) var product: Product?
    public private(set) var isSupporter = false
    public private(set) var isLoading = false
    public private(set) var isPurchasing = false
    public private(set) var isRestoring = false
    public private(set) var message: String?

    private var updatesTask: Task<Void, Never>?

    public init() {
        updatesTask = listenForTransactions()
    }

    /// Loads the localized StoreKit product and reconciles any previous gift.
    public func start() async {
        await loadProduct()
        await refreshEntitlement()
    }

    public func loadProduct() async {
        guard let productID = Self.productID, product == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            product = try await Product.products(for: [productID]).first
            if product == nil {
                message = "Support is unavailable. Try again later."
            } else {
                message = nil
            }
        } catch {
            product = nil
            message = "Support is unavailable. Try again later."
        }
    }

    /// Purchases the single non-consumable support product.
    public func purchase() async -> Bool {
        guard !isPurchasing, !isSupporter else { return false }
        if product == nil {
            await loadProduct()
        }
        guard let product else { return false }

        isPurchasing = true
        message = nil
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                setSupporter(true)
                await transaction.finish()
                return true
            case .success(.unverified):
                message = "The purchase could not be verified. If you were charged, contact Apple Support."
            case .pending:
                message = "The purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase could not be completed. Try again."
        }
        return false
    }

    /// Re-syncs the App Store account and restores a previous support gift.
    public func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        message = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isSupporter {
                message = "No previous \(GameIdentity.current.name) support purchase was found."
            }
        } catch {
            message = "Purchases could not be restored. Try again later."
        }
    }

    private func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            owned = true
        }
        // A just-finished purchase can take a moment to appear in
        // currentEntitlements in the StoreKit test environment. Do not erase
        // the verified in-session state while that purchase is still running.
        if owned || !isPurchasing {
            setSupporter(owned)
        }
    }

    private func setSupporter(_ value: Bool) {
        isSupporter = value
        if !value, Appearance.shared.theme == .dusk {
            Appearance.shared.theme = .primary
        }
        if !value {
            Appearance.shared.warmBackgroundEnabled = false
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                guard transaction.productID == Self.productID else { continue }
                await self?.refreshEntitlement()
            }
        }
    }
}
