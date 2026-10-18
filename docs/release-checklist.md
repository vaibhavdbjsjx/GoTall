# Release checklist: Linden 1.0.0

What's done in the code, and what only you can do (accounts, money, legal, a real iPhone). Work top to bottom.

## Done in the repo

- [x] Brand: name (Linden), icon (`App/Resources/Assets.xcassets/AppIcon.appiconset`), accent colour, display name, version 1.0.0 (build 1)
- [x] Bundle ID `app.linden.growth`; product IDs `app.linden.growth.premium.yearly` / `.monthly`
- [x] Privacy manifest (`App/Resources/PrivacyInfo.xcprivacy`); encryption export flag set (`ITSAppUsesNonExemptEncryption = NO`)
- [x] Privacy policy and terms shown in the app (work offline) and generated into `site/` (`scripts/build_site.py`). A test fails if they drift apart.
- [x] StoreKit 2 subscriptions with verification, restore, manage, Family Sharing, Ask to Buy; tested against the local StoreKit environment
- [x] Ask Linden on-device assistant with safety answers and an output guard; built-in guide fallback
- [x] Release build for device checked in CI; unit, StoreKit and UI tests in CI
- [x] App Store screenshots composed in CI (`store-screenshots/` in the CI artifact)
- [x] Listing text: `docs/app-store-listing.md`

## You need to do (in order)

1. **Check the name.**
   - Search the App Store and USPTO (tmsearch.uspto.gov) for "Linden" in health apps.
   - If it's taken, change `BrandConfig.displayName`, `APP_DISPLAY_NAME` in `App/project.yml` and the listing. The icon still works for most tree or leaf names.
2. **Apple Developer Program.**
   - Enrol ($99/year) at developer.apple.com.
   - Sign the Paid Apps agreement and add bank and tax details (App Store Connect › Business).
   - Apply for the App Store Small Business Program (15% commission).
3. **Publish the legal pages** (needed for App Store Connect).
   - Option A, GitHub Pages: rename this repo to `linden`, so the URLs in `BrandConfig` work as written and the URL doesn't carry a competitor's name. Then Settings › Pages › Source: GitHub Actions, then Actions › "Publish site" › Run workflow. Pages on a private repo needs a paid GitHub plan.
   - Option B: upload the `site/` folder to any static host (Netlify Drop, Cloudflare Pages) and update the three URLs in `BrandConfig.swift` and `docs/app-store-listing.md`.
   - Replace `SUPPORT_EMAIL` in `scripts/build_site.py` with a real address, then run `python3 scripts/build_site.py`.
4. **Legal review.** Have a lawyer read the privacy policy and terms (`Sources/GrowthCore/Brand/LegalDocuments.swift`), especially for children's privacy (COPPA) and US state app-store laws.
5. **Decide prices.**
   - Choose yearly and monthly prices. The $39.99 and $5.99 in `App/Products.storekit` are test values.
   - The app always shows the real App Store price, so no code change is needed.
6. **App Store Connect setup.**
   - Create the app with bundle ID `app.linden.growth`.
   - Create the subscription group and both subscriptions with exactly the product IDs above. Turn Family Sharing on.
   - Fill in the listing from `docs/app-store-listing.md`. App Privacy: "Data Not Collected".
   - Answer the age-rating questionnaire.
7. **Build on a Mac with Xcode 26.**
   - Run `brew install xcodegen && cd App && xcodegen generate`, then open `GrowthApp.xcodeproj`.
   - Set your Team under Signing & Capabilities for the GrowthApp target.
   - Add the In-App Purchase capability if Xcode asks.
8. **Test on a real iPhone.**
   - Sandbox purchase, restore and cancel (create a Sandbox tester in App Store Connect › Users and Access).
   - Turn reminders on and check that one actually arrives (set the daily time a few minutes ahead).
   - Ask Linden on an iPhone with Apple Intelligence (iPhone 15 Pro or later on iOS 26) and on one without it.
   - Generate and share a report. Check VoiceOver and the largest text size.
9. **Upload.** Product › Archive › Distribute App › App Store Connect. Test the build in TestFlight with a few parents first.
10. **Submit for review.**
    - Attach the six screenshots from the CI artifact (`store-screenshots/`).
    - Paste the review notes from the listing doc.
    - Submit the subscriptions together with the first version.

## After launch

- Watch conversion from paywall view to purchase, refunds, 1-star reviews and crash reports (Xcode Organizer).
- Run the pricing experiments in `docs/monetization-strategy.md` §3 only after a stable baseline.
