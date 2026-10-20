import Foundation
import StoreKit

/// The one-time unlock. StoreKit is the source of truth; the result is mirrored into
/// DraftQuota.isUnlocked so the share sheet can read it.
@MainActor
@Observable
final class PurchaseStore {
    static let productID = "com.alikhundmiri.dm-marketer.unlock"

    var product: Product?
    var isUnlocked = DraftQuota.isUnlocked
    var isWorking = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    func start() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            errorMessage = "Couldn't load the price. Check your connection."
        }
        await refreshEntitlements()
    }

    func buy() async {
        guard let product, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let result): await handle(result)
            case .pending: errorMessage = "Waiting for approval."
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isUnlocked { errorMessage = "No purchase found for this Apple account." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.productID {
            setUnlocked(transaction.revocationDate == nil)
        }
        await transaction.finish()
    }

    private func refreshEntitlements() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil {
                found = true
            }
        }
        setUnlocked(found)
    }

    private func setUnlocked(_ value: Bool) {
        isUnlocked = value
        DraftQuota.isUnlocked = value
    }
}
