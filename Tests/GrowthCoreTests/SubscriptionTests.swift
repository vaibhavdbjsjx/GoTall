import XCTest
@testable import GrowthCore

// MARK: Fakes

@MainActor
final class FakeSubscriptionService: SubscriptionService {
    var plansResult: Result<[SubscriptionPlan], SubscriptionError> = .success(FakeSubscriptionService.samplePlans)
    var purchaseOutcome: PurchaseOutcome = .purchased(EntitlementState(status: .active, productID: SubscriptionProductID.yearly))
    var restoreOutcome: RestoreOutcome = .nothingToRestore
    var entitlement: EntitlementState = .free
    var holdPurchase = false
    var heldPurchase: CheckedContinuation<Void, Never>?
    var updateHandler: (@MainActor (EntitlementState) -> Void)?
    var observeCount = 0

    static let samplePlans = [
        SubscriptionPlan(id: SubscriptionProductID.monthly, displayName: "Premium Monthly", displayPrice: "$5.99", price: Decimal(string: "5.99")!,
                         currencyCode: "USD", period: .month, isFamilyShareable: true),
        SubscriptionPlan(id: SubscriptionProductID.yearly, displayName: "Premium Yearly", displayPrice: "$39.99", price: Decimal(string: "39.99")!,
                         currencyCode: "USD", period: .year, isFamilyShareable: true)
    ]

    func loadPlans() async throws -> [SubscriptionPlan] { try plansResult.get() }

    func purchase(planID: String) async -> PurchaseOutcome {
        if holdPurchase { await withCheckedContinuation { heldPurchase = $0 } }
        return purchaseOutcome
    }

    func restore() async -> RestoreOutcome { restoreOutcome }
    func currentEntitlement() async -> EntitlementState { entitlement }
    func startObservingUpdates(_ handler: @escaping @MainActor (EntitlementState) -> Void) {
        observeCount += 1
        updateHandler = handler
    }
}

// MARK: Resolver and policy

final class EntitlementResolverTests: XCTestCase {
    let now = T.today

    func tx(_ product: String = SubscriptionProductID.yearly, expires days: Int?, revoked: Bool = false, upgraded: Bool = false,
            family: Bool = false, purchasedDaysAgo: Int = 30) -> TransactionSnapshot {
        TransactionSnapshot(productID: product, originalID: "1", purchaseDate: now.addingTimeInterval(Double(-purchasedDaysAgo) * 86_400),
                            expirationDate: days.map { now.addingTimeInterval(Double($0) * 86_400) },
                            revocationDate: revoked ? now.addingTimeInterval(-3600) : nil, isFamilyShared: family, isUpgraded: upgraded)
    }

    func testFreeWithoutTransactions() {
        let state = EntitlementResolver.resolve(transactions: [], renewals: [], now: now)
        XCTAssertEqual(state, .free)
        XCTAssertFalse(state.isPremium)
    }

    func testVerifiedActiveSubscriptionIsPremium() {
        let state = EntitlementResolver.resolve(transactions: [.verified(tx(expires: 300))],
                                                renewals: [.verified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .subscribed, willAutoRenew: true))], now: now)
        XCTAssertEqual(state.status, .active)
        XCTAssertTrue(state.isPremium)
        XCTAssertEqual(state.productID, SubscriptionProductID.yearly)
    }

    func testUnverifiedTransactionNeverUnlocks() {
        let state = EntitlementResolver.resolve(transactions: [.unverified(tx(expires: 300), reason: "bad signature")], renewals: [], now: now)
        XCTAssertFalse(state.isPremium)
        XCTAssertEqual(state, .free)
    }

    func testUnverifiedRenewalInfoIsIgnored() {
        // A forged "won't renew" or "grace period" can't change the verified state.
        let state = EntitlementResolver.resolve(transactions: [.verified(tx(expires: -2))],
                                                renewals: [.unverified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .inGracePeriod, willAutoRenew: true,
                                                                                       gracePeriodExpirationDate: now.addingTimeInterval(86_400 * 10)), reason: "x")], now: now)
        XCTAssertEqual(state.status, .expired)
    }

    func testExpiredSubscription() {
        let state = EntitlementResolver.resolve(transactions: [.verified(tx(expires: -1))], renewals: [], now: now)
        XCTAssertEqual(state.status, .expired)
        XCTAssertFalse(state.isPremium)
    }

    func testCancelledStaysPremiumUntilExpiry() {
        let state = EntitlementResolver.resolve(transactions: [.verified(tx(expires: 20))],
                                                renewals: [.verified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .subscribed, willAutoRenew: false))], now: now)
        XCTAssertEqual(state.status, .cancelled)
        XCTAssertTrue(state.isPremium)
        XCTAssertNotNil(state.expirationDate)
    }

    func testRevokedLosesAccess() {
        let state = EntitlementResolver.resolve(transactions: [.verified(tx(expires: 200, revoked: true))], renewals: [], now: now)
        XCTAssertEqual(state.status, .revoked)
        XCTAssertFalse(state.isPremium)
    }

    func testGracePeriodKeepsAccessBillingRetryDoesNot() {
        let grace = EntitlementResolver.resolve(transactions: [.verified(tx(expires: -1))],
                                                renewals: [.verified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .inGracePeriod, willAutoRenew: true,
                                                                                     gracePeriodExpirationDate: now.addingTimeInterval(86_400 * 5)))], now: now)
        XCTAssertEqual(grace.status, .gracePeriod)
        XCTAssertTrue(grace.isPremium)

        let retry = EntitlementResolver.resolve(transactions: [.verified(tx(expires: -1))],
                                                renewals: [.verified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .inBillingRetryPeriod, willAutoRenew: true))], now: now)
        XCTAssertEqual(retry.status, .billingRetry)
        XCTAssertFalse(retry.isPremium)
    }

    func testUpgradedAndUnknownProductsIgnoredLatestWins() {
        let state = EntitlementResolver.resolve(transactions: [
            .verified(tx(SubscriptionProductID.monthly, expires: 10, upgraded: true)),
            .verified(tx("com.other.app.pro", expires: 900)),
            .verified(tx(SubscriptionProductID.monthly, expires: 15)),
            .verified(tx(SubscriptionProductID.yearly, expires: 360))
        ], renewals: [], now: now)
        XCTAssertEqual(state.productID, SubscriptionProductID.yearly)
        XCTAssertTrue(state.isPremium)
    }

    func testVerifiedStatusOverridesStaleTransaction() {
        // A cached transaction still says it runs for 300 days, but Apple's verified status says it ended.
        let expired = EntitlementResolver.resolve(transactions: [.verified(tx(expires: 300))],
                                                  renewals: [.verified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .expired, willAutoRenew: false))], now: now)
        XCTAssertEqual(expired.status, .expired)
        XCTAssertFalse(expired.isPremium)
        let refunded = EntitlementResolver.resolve(transactions: [.verified(tx(expires: 300))],
                                                   renewals: [.verified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .revoked, willAutoRenew: false))], now: now)
        XCTAssertEqual(refunded.status, .revoked)
        // An unverified "expired" status can't remove access either.
        let forged = EntitlementResolver.resolve(transactions: [.verified(tx(expires: 300))],
                                                 renewals: [.unverified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .expired, willAutoRenew: false), reason: "x")], now: now)
        XCTAssertTrue(forged.isPremium)
        // Mixed statuses (e.g. own + family-shared) keep access while any is still subscribed.
        let mixed = EntitlementResolver.resolve(transactions: [.verified(tx(expires: 300))], renewals: [
            .verified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .expired, willAutoRenew: false)),
            .verified(RenewalSnapshot(productID: SubscriptionProductID.yearly, state: .subscribed, willAutoRenew: true))], now: now)
        XCTAssertTrue(mixed.isPremium)
    }

    func testFamilySharingRecorded() {
        let state = EntitlementResolver.resolve(transactions: [.verified(tx(expires: 100, family: true))], renewals: [], now: now)
        XCTAssertTrue(state.isFamilyShared)
        XCTAssertTrue(state.isPremium)
    }

    func testPolicyCentralisesAccess() {
        for feature in PremiumFeature.allCases {
            XCTAssertEqual(EntitlementPolicy.access(feature, state: .free), .preview)
            XCTAssertEqual(EntitlementPolicy.access(feature, state: EntitlementState(status: .active)), .available)
            XCTAssertEqual(EntitlementPolicy.access(feature, state: EntitlementState(status: .expired)), .preview)
        }
    }

    func testProfilesAreGrandfatheredOnlyAddingIsGated() {
        XCTAssertTrue(EntitlementPolicy.canAddProfile(existingCount: 0, state: .free), "first profile is always free")
        XCTAssertFalse(EntitlementPolicy.canAddProfile(existingCount: 1, state: .free))
        XCTAssertTrue(EntitlementPolicy.canAddProfile(existingCount: 3, state: EntitlementState(status: .active)))
        // Existing profiles are untouched: the policy has no notion of "locking" a profile.
        XCTAssertFalse(EntitlementPolicy.canAddProfile(existingCount: 3, state: EntitlementState(status: .expired)))
    }

    func testPlanPricingTextIsComputedFromRealPrices() {
        let monthly = FakePlans.monthly, yearly = FakePlans.yearly
        XCTAssertEqual(yearly.monthlyEquivalent(locale: Locale(identifier: "en_US")), "$3.33")
        XCTAssertNil(monthly.monthlyEquivalent())
        XCTAssertEqual(yearly.savingPercent(comparedTo: monthly), 44)
        XCTAssertNil(monthly.savingPercent(comparedTo: yearly))
        XCTAssertTrue(yearly.billingTerms.contains("$39.99"))
        XCTAssertTrue(yearly.billingTerms.lowercased().contains("cancel"))
        XCTAssertTrue(yearly.billingTerms.contains("24 hours"))
        XCTAssertEqual(yearly.priceLine, "$39.99 per year")
        XCTAssertNil(yearly.introductoryOffer, "launch plan has no trial")
    }
}

enum FakePlans {
    static let monthly = SubscriptionPlan(id: SubscriptionProductID.monthly, displayName: "Premium Monthly", displayPrice: "$5.99",
                                          price: Decimal(string: "5.99")!, currencyCode: "USD", period: .month, isFamilyShareable: true)
    static let yearly = SubscriptionPlan(id: SubscriptionProductID.yearly, displayName: "Premium Yearly", displayPrice: "$39.99",
                                         price: Decimal(string: "39.99")!, currencyCode: "USD", period: .year, isFamilyShareable: true)
}

// MARK: Paywall model and entitlement store

final class PaywallModelTests: XCTestCase {
    @MainActor
    func make() -> (FakeSubscriptionService, EntitlementStore, PaywallModel) {
        let service = FakeSubscriptionService()
        let store = EntitlementStore(service: service)
        return (service, store, PaywallModel(store: store))
    }

    @MainActor
    func testLoadsPlansYearlyFirstAndSelected() async {
        let (_, _, model) = make()
        XCTAssertEqual(model.plans, .loading)
        await model.loadPlans()
        XCTAssertEqual(model.loadedPlans.map(\.period), [.year, .month])
        XCTAssertEqual(model.selectedPlan?.id, SubscriptionProductID.yearly)
        XCTAssertEqual(model.monthlyPlan?.id, SubscriptionProductID.monthly)
    }

    @MainActor
    func testLoadFailureShowsUsefulMessage() async {
        let (service, _, model) = make()
        service.plansResult = .failure(.network)
        await model.loadPlans()
        XCTAssertEqual(model.plans, .failed(SubscriptionError.network.message))
        service.plansResult = .success([])
        await model.loadPlans()
        XCTAssertEqual(model.plans, .failed(SubscriptionError.productsUnavailable.message))
    }

    @MainActor
    func testPurchaseShowsLoadingThenSuccessAndUnlocks() async {
        let (service, store, model) = make()
        await model.loadPlans()
        service.holdPurchase = true
        let task = Task { await model.purchaseSelected() }
        while service.heldPurchase == nil { await Task.yield() }
        XCTAssertEqual(model.purchase, .purchasing(planID: SubscriptionProductID.yearly))
        XCTAssertTrue(model.isBusy)
        await model.purchaseSelected() // ignored while busy
        service.heldPurchase?.resume()
        await task.value
        XCTAssertEqual(model.purchase, .succeeded)
        XCTAssertTrue(store.isPremium)
        XCTAssertTrue(store.justUnlocked)
        XCTAssertEqual(store.access(.doctorReport), .available)
        XCTAssertEqual(model.statusMessage, "Premium is active.")
    }

    @MainActor
    func testCancellationIsNeutralNotAnError() async {
        let (service, store, model) = make()
        await model.loadPlans()
        service.purchaseOutcome = .cancelled
        await model.purchaseSelected()
        XCTAssertEqual(model.purchase, .cancelled)
        XCTAssertEqual(model.statusMessage, "Purchase cancelled.")
        XCTAssertFalse(store.isPremium)
    }

    @MainActor
    func testFailureAndRetry() async {
        let (service, store, model) = make()
        await model.loadPlans()
        service.purchaseOutcome = .failed("The App Store couldn't complete the purchase.")
        await model.purchaseSelected()
        XCTAssertEqual(model.purchase, .failed("The App Store couldn't complete the purchase."))
        XCTAssertFalse(store.isPremium)
        service.purchaseOutcome = .purchased(EntitlementState(status: .active, productID: SubscriptionProductID.yearly))
        await model.purchaseSelected()
        XCTAssertEqual(model.purchase, .succeeded)
    }

    @MainActor
    func testUnconfirmedPurchaseDoesNotUnlock() async {
        let (service, store, model) = make()
        await model.loadPlans()
        service.purchaseOutcome = .purchased(.free)
        await model.purchaseSelected()
        XCTAssertFalse(store.isPremium)
        if case .failed = model.purchase {} else { XCTFail("expected failure, got \(model.purchase)") }
    }

    @MainActor
    func testPendingAskToBuy() async {
        let (service, store, model) = make()
        await model.loadPlans()
        service.purchaseOutcome = .pending
        await model.purchaseSelected()
        XCTAssertEqual(model.purchase, .pending)
        XCTAssertFalse(store.isPremium)
        XCTAssertTrue(model.statusMessage?.contains("approval") == true)
    }

    @MainActor
    func testRestore() async {
        let (service, store, model) = make()
        await model.restore()
        XCTAssertEqual(model.purchase, .nothingToRestore)
        XCTAssertFalse(store.isPremium)
        service.restoreOutcome = .restored(EntitlementState(status: .active, productID: SubscriptionProductID.monthly))
        await model.restore()
        XCTAssertEqual(model.purchase, .succeeded)
        XCTAssertTrue(store.isPremium)
    }

    @MainActor
    func testStoreRecoversOnLaunchAndFollowsUpdates() async {
        let service = FakeSubscriptionService()
        service.entitlement = EntitlementState(status: .active, productID: SubscriptionProductID.yearly)
        let store = EntitlementStore(service: service)
        XCTAssertFalse(store.isPremium, "nothing unlocked before verification")
        await store.start()
        await store.start()
        XCTAssertEqual(service.observeCount, 1, "no duplicate listeners")
        XCTAssertTrue(store.isPremium, "relaunch recovers Premium from verified on-device transactions")
        service.updateHandler?(EntitlementState(status: .expired, productID: SubscriptionProductID.yearly))
        XCTAssertFalse(store.isPremium)
        XCTAssertEqual(store.access(.advancedAnalytics), .preview, "previews return after expiry")
        service.updateHandler?(EntitlementState(status: .cancelled, productID: SubscriptionProductID.yearly, expirationDate: T.today))
        XCTAssertTrue(store.isPremium)
    }

    func testPremiumOfferOnlyAfterRealValue() {
        let analyzer = GrowthAnalyzer(now: T.today, calendar: T.calendar)
        func profile(_ ms: [(Date, Double)]) -> GrowthProfile {
            GrowthProfile(subject: .myself, birthDate: T.date(2012, 4, 1), chartSex: .male, unitPreference: .centimeters,
                          measurements: ms.map { HeightMeasurement(date: $0.0, heightCm: $0.1, method: .home, origin: .manual) }, createdAt: T.today, updatedAt: T.today)
        }
        let trend = analyzer.analyze(profile([(T.date(2025, 9, 1), 150), (T.date(2026, 9, 1), 156)]))
        let single = analyzer.analyze(profile([(T.date(2026, 9, 1), 156)]))
        XCTAssertTrue(PremiumOfferPolicy.shouldSuggest(analysis: trend, isPremium: false, dismissedAt: nil, now: T.today, calendar: T.calendar))
        XCTAssertFalse(PremiumOfferPolicy.shouldSuggest(analysis: single, isPremium: false, dismissedAt: nil, now: T.today, calendar: T.calendar))
        XCTAssertFalse(PremiumOfferPolicy.shouldSuggest(analysis: trend, isPremium: true, dismissedAt: nil, now: T.today, calendar: T.calendar))
        XCTAssertFalse(PremiumOfferPolicy.shouldSuggest(analysis: trend, isPremium: false, dismissedAt: T.date(2026, 9, 1), now: T.today, calendar: T.calendar))
        XCTAssertTrue(PremiumOfferPolicy.shouldSuggest(analysis: trend, isPremium: false, dismissedAt: T.date(2026, 5, 1), now: T.today, calendar: T.calendar))
    }
}
