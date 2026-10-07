# Phase 5: Commercial Product Layer

Premium experience, StoreKit 2, doctor-ready report and local notifications. This builds on `monetization-strategy.md` (which supersedes `monetization.md`), `mvp-scope.md` and `phase-4-design.md`.

## 1. How Premium fits the design system (audit before building)

| Question | Decision |
|---|---|
| Separate "paywall look"? | No. Premium uses the same Spruce surfaces, type scale, `heroSurface`, `dsSurface`, `AppButton` and motion. Premium is marked with a quiet outline `PremiumBadge`: no gold, no crowns, no gradients. |
| Where can Premium appear? | (1) Profile › Premium card; (2) the feature itself, as a labelled preview (report preview, advanced analysis, adding a profile); (3) one dismissible Home card, only after a growth trend exists. Never at launch, never in onboarding. |
| What a locked feature looks like | `LockedFeaturePreview`: title, Premium badge, a box labelled "PREVIEW · FROM YOUR MEASUREMENTS" with one sentence computed from the person's own data, what Premium adds, and "Explore Premium". It contains no invented numbers. |
| The paywall's job | To answer "why pay?" with concrete benefits, show what stays free, then show the full price, billing period, renewal and cancellation terms *before* the button. The close button is always visible. |

New components (`Sources/DesignSystem/Components/Premium.swift`):
- `PremiumBadge`, `PremiumFeatureRow`, `BenefitCard`
- `ReportPreview`: an abstract miniature of the PDF, with no numbers
- `PaywallHero`, `PriceOption`, `PurchaseButton`, `RestorePurchaseButton`
- `ManageSubscriptionRow`, `SubscriptionCard`, `LockedFeaturePreview`

## 2. StoreKit 2 architecture

```
StoreKitSubscriptionService (AppFeatures, StoreKit 2)
   │  Product.products · product.purchase() · Transaction.currentEntitlements / latest(for:)
   │  Transaction.updates · Product.SubscriptionInfo.Status.updates · AppStore.sync()
   ▼  maps StoreKit types to platform-neutral snapshots (TransactionSnapshot, RenewalSnapshot, Verified<…>)
SubscriptionService protocol (GrowthCore)
   ▼
EntitlementResolver (pure, unit-tested) ──► EntitlementState (status, product, expiry, family-shared)
   ▼
EntitlementStore (@Observable) ──► EntitlementPolicy.access(feature) / canAddProfile(...)
   ▼
Views ask only `entitlements.access(.doctorReport)`. No `if premium` checks are spread around the UI.
```

- **Verification:** only `VerificationResult.verified` values reach the resolver as trusted. StoreKit verifies the JWS signature on the device, so no secret is shipped and no server is needed. An unverified purchase returns a failure ("nothing was unlocked") and is not finished.
- **States handled:**
  - free (`none`)
  - `active`
  - `cancelled`: still Premium until the expiry date, renewal off
  - `gracePeriod`: Premium kept while Apple retries billing
  - `billingRetry`: access paused
  - `expired`
  - `revoked`: refund, or Family Sharing removed
  - family-shared (flag)
  - upgraded transactions ignored
  - unknown product IDs ignored
- **Apple's status is authoritative.** If every verified subscription status for a product says expired or revoked, that product grants nothing, even when `currentEntitlements` still returns a cached transaction with a later expiry date. The app-hosted StoreKit tests found this lag after an expiry and a refund. Unverified statuses are ignored, so they can neither grant nor remove access.
- **Launch / relaunch / offline:**
  - `EntitlementStore` starts as free and unlocks nothing before verification.
  - `start()` recomputes from `Transaction.currentEntitlements`, which the OS caches on the device, so Premium is recovered offline without a server.
  - It also refreshes on every return to the foreground and after the Manage Subscriptions sheet closes.
- **Updates:** listeners for `Transaction.updates` (renewals, refunds, Ask to Buy approvals, purchases on other devices) and `Product.SubscriptionInfo.Status.updates` (auto-renew changes). Transactions are finished after verification.
- **No RevenueCat.** There is no concrete need yet: no server-side entitlement checks (no AI coach), and no experiments platform at launch. That matches `monetization-strategy.md` §6.

## 3. Entitlements and the free/premium boundary

| Free, always | Premium |
|---|---|
| Height, percentile, growth chart (both ranges) | Doctor-ready PDF report (the preview screen is free) |
| Adult-height estimate + full explanation | Advanced growth analysis: percentile history chart, speed between every measurement pair, estimate history |
| Family-height range | Adding a second or later profile |
| Free growth speed, insights, safety signposts | Planned additions (labelled "Planned") |
| Unlimited measurement history, editing | |
| Habits, consistency, weekly summary | |
| All reminders | |
| Export (JSON) and delete | |

**Family profiles (migration-safe).** `EntitlementPolicy.canAddProfile(existingCount:state:)` gates only *adding* a profile beyond the first.
- Profiles that already exist are never locked: switching, editing, measuring and the free analysis all keep working. This covers Phase 2–4 builds where profiles were unlocked, and expired subscriptions.
- The switcher shows "Family profiles are part of Premium. Every profile here stays free to use." next to "Add a child", and the button opens the paywall with a family-specific first line.

## 4. Products and prices

- **Group:** "Premium".
  - `com.example.growthapp.premium.yearly` (P1Y)
  - `com.example.growthapp.premium.monthly` (P1M)
  - Family Sharing on for both.
  - No trial and no introductory offer: stage 1 of the experiment plan in `monetization-strategy.md` §3.2. The code displays an intro offer if one is ever configured.
- **Prices are not decided in code.** The UI shows `Product.displayPrice` from the App Store.
  - `App/Products.storekit` holds test values ($39.99/year, $5.99/month), labelled "test price". They sit within the observed competitor range and exist only so the flow can be exercised.
  - Final prices come from the stage 0 research before launch.
- **Derived numbers are computed, not invented:**
  - "Works out at $3.33 a month, billed once a year" (rounded down).
  - "Save 44%", only when it's at least 1%, computed against 12 × the real monthly price. There's never a fake "original" price.
- **Bundle IDs are placeholders** (`com.example.*`) until the brand is final.

## 5. Paywall UX

Order: hero ("Go deeper with your growth profile." plus what stays free) → optional context line (why it opened) → four benefit cards (one labelled Planned) → "Always free" list → plans → billing terms → Terms / Privacy / Restore → pinned purchase button.

- **The purchase button** always contains the price and period ("Subscribe · $39.99/year"). It's pinned at standard text sizes. At accessibility sizes it scrolls with the content, so it never covers the pricing.
- **Billing terms** for the selected plan, in full: "Billed $39.99 every year until you cancel. Renews automatically unless cancelled at least 24 hours before the end of the current period. Cancel anytime in Settings › Apple Account › Subscriptions." Plus a Family Sharing note and "Payment is handled by Apple. Your growth data stays on this device…".
- **States** (`PaywallModel`):
  - loading: placeholders
  - prices unavailable: message + Try again
  - purchasing: "Confirming with the App Store", spinner, controls disabled
  - **cancelled: "Purchase cancelled."**, neutral and not an error
  - pending (Ask to Buy): "Waiting for approval…"
  - failed: message + "Try again · price"
  - restore: none found / restored / failed
  - success: `PremiumActiveView` with a calm seal, status line and where to find each feature
  - Status changes are announced to VoiceOver.
- **Not used:** timers, countdowns, scarcity, a delayed close button, pre-selected trials, a launch paywall, an onboarding paywall, confirmshaming. Yearly is pre-selected, with both prices fully visible and no trial attached.

## 6. Free → Premium moments

`PremiumOfferPolicy.shouldSuggest`: the person isn't Premium, growth speed is available (two or more careful measurements at least 6 months apart, so they have a real trend), and they haven't dismissed the card in the last 60 days. Then Home shows one card ("A clear report for the doctor", "See what's included" / "Not now"). Other entry points are contextual: report Generate, Advanced analysis, Add a child, and Profile › Explore Premium.

## 7. Doctor-ready report

- **Model:**
  - `GrowthReportBuilder` (GrowthCore, pure, unit-tested) builds a `GrowthReport` with a cover, 10 numbered sections, section statuses for the preview screen, and the four required statements:
    - "This report is not a diagnosis."
    - "Estimates are not guarantees."
    - "Growth charts provide context, not a verdict on any individual."
    - "This report does not replace evaluation by a qualified healthcare professional."
  - Missing data is explained, not hidden ("Not available: growth speed needs two measurements at least 6 months apart.").
  - Imperial reports keep centimetres in brackets for clinicians.
  - Habits can't change the report (tested).
- **Rendering:**
  - `ReportPDFRenderer`: CoreGraphics + CoreText, no UIKit.
  - It runs in the app off the main thread (`Task.detached`), and in the macOS CI tests. Those tests check the text via PDFKit and rasterise each page to PNG for visual review.
  - US Letter (US storefront), two passes so footers read "Page n of N", header with name and report date on every page after the cover.
- **Design:**
  - Cover: brand eyebrow, title, profile grid, "At a glance", a "Please read" box with the required statements, and contents with each section's status.
  - Sections have numbered headings and rules.
  - Tables have header fills, row rules and a repeated header after a page break.
  - The chart shows CDC percentile curves 3–97 (3rd and 97th dashed, 50th heavier), the shaded 25–75 band, the measurement line, hollow points for estimates, axis labels and a legend. Lines are at least 0.5 pt and text at least 7.5 pt for printing.
- **Preview screen:**
  - Unit choice, what's included (with notes for limited sections), "From your data", the not-a-diagnosis note, and Generate.
  - Free users see everything; Generate opens the paywall.
  - Ready state: View (QuickLook) and Share or print.
  - Failure message: "The report couldn't be created. Your data is unchanged…".
- **Privacy:** generated on the device and written to the temporary directory with complete file protection. Nothing is uploaded.

## 8. Notifications

- **Planner** (`NotificationPlanner`, pure). All categories are off by default. IDs are deterministic (`growth.measure.<profile>`, `growth.checkin.<day>`, `growth.weekly.<day>`).
  - **Measurement:** one per profile at 10:00 when due (the recommended interval by age, or a custom 1/2/3/4/6/12 months); tomorrow if already due. A new measurement moves it. Adults get none on Recommended.
  - **Daily check-in:** a rolling 7 days of one-off reminders at Morning (8:00), Afternoon (13:00), Evening (19:00) or a custom time. Today is skipped once anyone has checked in. After a week without opening the app the reminders stop, which avoids nagging. Copy: "Daily check-in / Your daily check-in is ready."
  - **Weekly summary:** next Sunday 18:00, *only* if the past week had 3 or more check-in days or a measurement. Copy: "Your week in review is ready." The notification carries no statistics; tapping it opens `WeeklySummaryView`, which computes them live.
- **Reconciler** (`NotificationReconciler`): diffs the system's pending requests against the plan.
  - Unchanged reminders are left alone; changed ones are replaced; stale ones are removed (disabled category, moved date, deleted profile); duplicate IDs are collapsed.
  - Other apps' or other features' requests (different prefix) are never touched.
- **Coordinator** (`NotificationCoordinator`):
  - `setCategory` asks iOS for permission only when a reminder is turned on. If permission was denied, the preference stays off and the screen offers "Open Settings".
  - `sync` coalesces overlapping calls, so nothing is scheduled twice.
  - It is triggered at launch, on returning to the foreground, and on any data change (measurement, preferences, profile, habit).
  - All scheduling logic is outside views.
- **iOS adapter:** `UserNotificationScheduler` (calendar triggers, the route in `userInfo`). `NotificationTapRouter` routes taps to Add measurement (with the right profile active), Habits, or the weekly summary, and shows banners while the app is open.
- **Contextual ask:** after saving a measurement, the success screen offers "Remind me when it's time to measure again", then shows "Reminder set for …".

## 9. Profile

Grouped by purpose:
- **Header card.**
- **Premium:** status card with plan and renewal/end date, or the grace / billing-retry / expired / revoked wording. Manage subscription opens Apple's sheet; Restore purchases is always present.
- **Tools:** doctor-ready report, reminders, your week.
- **Profiles.**
- **Growth.**
- **Preferences:** unit, appearance.
- **Privacy & data:** export, delete, with a note that deleting data doesn't cancel a subscription.
- **About.**

## 10. App Store compliance review

| Requirement | Status |
|---|---|
| 3.1.1 IAP for digital features | StoreKit only |
| 3.1.2 auto-renew disclosure: title, length, price, renewal, cancel | On the paywall, before the button |
| Terms of Use (EULA) link | Apple standard EULA, linked from the paywall |
| Privacy policy link | **Launch blocker:** `BrandConfig.privacyPolicyURL` is nil, so an in-app privacy summary is shown instead. A hosted policy is needed before submission. |
| Restore purchases | Paywall + Profile |
| Manage / cancel | `manageSubscriptionsSheet` in Profile |
| No misleading pricing or urgency | Real prices only; computed saving; no timers |
| Family Sharing / Ask to Buy | Enabled; pending state handled |
| 1.4.1 health claims | Report and paywall are non-diagnostic (tested with CopyGuard). No "accuracy", no "grow taller". |
| Kids / teens | No paywall in onboarding; purchases go through Apple (Ask to Buy). Parent-facing copy for child profiles. |
| 5.1.1(v) data deletion | No accounts; delete all on the device |
| Notification permission | Requested in context only; the app works fully without it |
| Account requirement | None |

Other launch blockers:
- Products must exist in App Store Connect with final prices.
- Paid Apps agreement.
- Small Business Program enrolment.
- Final bundle ID.
- Legal review of subscription terms (`mvp-scope.md` §137).
- A sandbox test on a real device.

## 11. Privacy and performance

- No backend was added. StoreKit verification happens on the device. Growth data never leaves the device to buy a subscription, check one, or make a report.
- PDF rendering runs off the main thread. Entitlement refreshes and notification syncs are async and never block the UI.

## 12. Tests

- **GrowthCore (Linux + macOS):**
  - Resolver: free, active, unverified, forged renewal, expired, cancelled, revoked, grace, billing retry, upgraded/unknown, family.
  - Policy and profile grandfathering; plan maths.
  - `PaywallModel`: loading, failure, purchasing → success, cancellation, failure → retry, unconfirmed, pending, restore.
  - `EntitlementStore`: launch recovery, updates, expiry.
  - Offer policy.
  - Report: contents, required statements, chart, metric vs imperial, missing data, wording, advanced analysis, habit independence.
  - On macOS, the PDF test also checks text via PDFKit and renders pages.
  - Notifications: planner, reconciler and coordinator (permission once, denied, disable cancels, repeated sync no duplicates, measurement reschedule, preference and profile changes, foreign requests untouched), routes, decoding.
- **App-hosted StoreKit tests** (`App/Tests/StoreKit`, `SKTestSession` + `Products.storekit`): plans load, free before purchase, verified purchase → Premium, relaunch recovery, expiry, cancellation, refund, restore, nothing to restore, Ask to Buy → approval via updates, simulated verification failure, store + paywall model end to end.
- **UI tests** (`App/Tests/UI`): open Profile → Premium → paywall (prices, terms, restore, plan switch) → close; purchase progress → success; cancelled is neutral; failure → retry; notification settings enable/disable against the real notification center with the system permission prompt; report preview → generate → ready; free report → paywall; core result free.
