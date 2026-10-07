import XCTest
import StoreKit
import StoreKitTest
import GrowthCore
import AppFeatures

/// Runs the real `StoreKitSubscriptionService` against Apple's local StoreKit test environment
/// (`Products.storekit`). Transactions here are signed by Xcode's test certificate and go through the same
/// `VerificationResult` path as production.
@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session.clearTransactions()
    }

    /// Test-session changes (expire, refund, auto-renew off) reach StoreKit asynchronously, as they would arrive
    /// through `Transaction.updates` in the app. Polls until the state matches or the timeout passes.
    private func awaitState(of service: StoreKitSubscriptionService, within seconds: Double = 10,
                       until predicate: (EntitlementState) -> Bool) async -> EntitlementState {
        var state = await service.currentEntitlement()
        let deadline = Date().addingTimeInterval(seconds)
        while !predicate(state) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 300_000_000)
            state = await service.currentEntitlement()
        }
        return state
    }

    func testLoadsBothPlansFromConfiguration() async throws {
        let plans = try await StoreKitSubscriptionService().loadPlans()
        XCTAssertEqual(Set(plans.map(\.id)), Set(SubscriptionProductID.all))
        let yearly = try XCTUnwrap(plans.first { $0.id == SubscriptionProductID.yearly })
        XCTAssertEqual(yearly.period, .year)
        XCTAssertTrue(yearly.isFamilyShareable)
        XCTAssertNil(yearly.introductoryOffer, "no trial at launch")
        XCTAssertFalse(yearly.displayPrice.isEmpty)
        XCTAssertNotNil(yearly.monthlyEquivalent())
    }

    func testFreeBeforePurchase() async {
        let state = await StoreKitSubscriptionService().currentEntitlement()
        XCTAssertFalse(state.isPremium)
        XCTAssertEqual(state.status, .none)
    }

    func testPurchaseProducesVerifiedPremium() async {
        let service = StoreKitSubscriptionService()
        let outcome = await service.purchase(planID: SubscriptionProductID.yearly)
        guard case .purchased(let state) = outcome else { return XCTFail("unexpected \(outcome)") }
        XCTAssertTrue(state.isPremium)
        XCTAssertEqual(state.productID, SubscriptionProductID.yearly)
        XCTAssertEqual(state.status, .active)
        let relaunch = await StoreKitSubscriptionService().currentEntitlement()
        XCTAssertTrue(relaunch.isPremium, "a fresh service (app relaunch) recovers Premium from verified transactions")
    }

    func testExpiryRemovesAccess() async throws {
        let service = StoreKitSubscriptionService()
        _ = await service.purchase(planID: SubscriptionProductID.monthly)
        try session.expireSubscription(productIdentifier: SubscriptionProductID.monthly)
        let state = await awaitState(of: service) { !$0.isPremium }
        XCTAssertFalse(state.isPremium)
        XCTAssertEqual(state.status, .expired)
    }

    func testCancellationKeepsAccessUntilPeriodEnds() async throws {
        let service = StoreKitSubscriptionService()
        _ = await service.purchase(planID: SubscriptionProductID.yearly)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        let state = await awaitState(of: service) { $0.status == .cancelled }
        XCTAssertTrue(state.isPremium)
        XCTAssertEqual(state.status, .cancelled)
    }

    func testRefundRevokesAccess() async throws {
        let service = StoreKitSubscriptionService()
        _ = await service.purchase(planID: SubscriptionProductID.yearly)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        let state = await awaitState(of: service) { !$0.isPremium }
        XCTAssertFalse(state.isPremium)
        XCTAssertEqual(state.status, .revoked)
    }

    func testRestoreFindsAnExistingPurchase() async throws {
        _ = try await session.buyProduct(identifier: SubscriptionProductID.yearly)
        let outcome = await StoreKitSubscriptionService().restore()
        guard case .restored(let state) = outcome else { return XCTFail("unexpected \(outcome)") }
        XCTAssertTrue(state.isPremium)
    }

    func testRestoreWithNothingToRestore() async {
        let outcome = await StoreKitSubscriptionService().restore()
        XCTAssertEqual(outcome, .nothingToRestore)
    }

    func testAskToBuyIsPendingThenUnlocksThroughUpdates() async throws {
        session.askToBuyEnabled = true
        let service = StoreKitSubscriptionService()
        let unlocked = expectation(description: "premium after approval")
        service.startObservingUpdates { state in
            if state.isPremium { unlocked.fulfill() }
        }
        let outcome = await service.purchase(planID: SubscriptionProductID.yearly)
        XCTAssertEqual(outcome, .pending)
        let pending = await service.currentEntitlement()
        XCTAssertFalse(pending.isPremium)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        await fulfillment(of: [unlocked], timeout: 10)
    }

    func testFailedVerificationNeverUnlocks() async throws {
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        let service = StoreKitSubscriptionService()
        let outcome = await service.purchase(planID: SubscriptionProductID.yearly)
        if case .purchased(let state) = outcome { XCTAssertFalse(state.isPremium, "unverified purchase must not unlock") }
        let state = await service.currentEntitlement()
        XCTAssertFalse(state.isPremium)
        try await session.setSimulatedError(nil, forAPI: .verification)
    }

    func testEntitlementStoreAppliesPurchaseAndFollowsExpiry() async throws {
        let store = EntitlementStore(service: StoreKitSubscriptionService())
        await store.start()
        XCTAssertFalse(store.isPremium)
        let model = PaywallModel(store: store)
        await model.loadPlans()
        await model.purchaseSelected()
        XCTAssertEqual(model.purchase, .succeeded)
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(store.access(.doctorReport), .available)
        try session.expireSubscription(productIdentifier: SubscriptionProductID.yearly)
        let service = StoreKitSubscriptionService()
        _ = await awaitState(of: service) { !$0.isPremium }
        await store.refresh()
        XCTAssertFalse(store.isPremium)
        XCTAssertEqual(store.access(.doctorReport), .preview)
    }
}
