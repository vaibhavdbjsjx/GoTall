# App Store listing: Linden (v1.0.0)

Ready-to-paste metadata for App Store Connect. The character limits are Apple's. Name availability and trademark clearance haven't been checked yet (see `release-checklist.md`).

## Identity

| Field | Value | Notes |
|---|---|---|
| App name (30) | **Linden: Growth & Height Chart** | 29 characters |
| Subtitle (30) | **Kids growth tracker & report** | 28 characters |
| Bundle ID | `app.linden.growth` | Must match App Store Connect |
| SKU | `linden-ios-001` | Any unique string |
| Primary category | Health & Fitness | |
| Secondary category | Medical | Optional. Expect closer review of health claims; the app makes none. |
| Price | Free with in-app subscriptions | |

## Keywords (100, comma-separated, no spaces)

```
height,percentile,growth chart,kids,child,teen,CDC,pediatric,tracker,measure,puberty,report,parents
```
(99 characters.) Don't add competitor names.

## Promotional text (170, editable any time)

> Track height on real CDC growth charts, see an honest adult-height estimate with its reasoning, and ask Linden questions answered privately on your iPhone.

## Description (4000)

> Linden helps parents, teens and adults understand growth: honestly, beautifully and privately.
>
> REAL GROWTH CHARTS
> • Height percentiles from the CDC 2000 growth charts, explained in plain words ("of 100 people the same age and sex, about 42 are shorter")
> • A clear chart with your measurements over the percentile curves
> • Growth speed from measurements at least 6 months apart, the way clinicians read it
>
> AN HONEST ADULT-HEIGHT ESTIMATE
> • See where height would land if growth stays in its current percentile channel, with the reasoning behind it
> • A range that's never presented as a guarantee, with puberty and measuring differences explained
> • Family-height context from both parents' heights, shown alongside the estimate and never mixed into it
>
> ASK LINDEN
> • Ask questions about your growth: the estimate, percentiles, growth speed, sleep, food, activity or measuring
> • Answers use your saved measurements and are made on your iPhone. Nothing is sent anywhere.
> • Conversational answers on iPhones with Apple Intelligence; Linden's built-in guide on other iPhones
> • Careful by design: no invented numbers, no medical claims, no "grow taller" tricks
>
> CALM DAILY HABITS
> • Gentle check-ins for sleep, activity, meals and water
> • A forgiving rhythm that never shames a missed day
> • Habits support healthy growth; they never change any height number
>
> DOCTOR-READY REPORT (PREMIUM)
> • A clean PDF with the growth chart, every measurement, percentile history, growth speed, methods and limitations
> • Made on your iPhone, ready to share or print at the next check-up
>
> FAMILY & PRIVACY
> • Track several children in one place (Premium adds profiles; the profiles you already have are always yours)
> • No accounts, no ads, no tracking. Your data stays on your device.
> • Export or delete everything at any time
>
> LINDEN PREMIUM
> Doctor-ready reports, advanced growth analysis, family profiles and unlimited Ask Linden. Your growth result, chart, estimate and history are always free.
> Payment is charged to your Apple Account. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple Account › Subscriptions.
>
> Linden provides information, not medical advice, and does not diagnose any condition. Talk to a doctor about any health concern.
>
> Privacy Policy: https://vaibhavdbjsjx.github.io/linden/privacy.html
> Terms of Use: https://vaibhavdbjsjx.github.io/linden/terms.html

## What's New (v1.0.0)

> Welcome to Linden. Real growth charts, an honest estimate, Ask Linden and a doctor-ready report, all private on your iPhone.

## URLs

| Field | URL |
|---|---|
| Privacy Policy URL | https://vaibhavdbjsjx.github.io/linden/privacy.html |
| Support URL | https://vaibhavdbjsjx.github.io/linden/support.html |
| Marketing URL (optional) | https://vaibhavdbjsjx.github.io/linden/ |

These work once `site/` is published (see `release-checklist.md` step 3). If you host elsewhere, update `BrandConfig` and this table.

## App Privacy ("nutrition label")

- **Data collection:** select "No, we do not collect data from this app". It's true: there's no server, analytics or third-party SDK, and StoreKit purchases are processed by Apple.
- **Tracking:** No.
- The privacy manifest (`App/Resources/PrivacyInfo.xcprivacy`) declares no tracking and no collected data, plus UserDefaults use with reason CA92.1.

## Age rating questionnaire (guidance)

Answer honestly in App Store Connect:
- No violence, mature themes, gambling, user-generated content, web browsing or messaging.
- "Medical or treatment information": the app shows growth-chart information and general wellness guidance, with no treatment advice. Most developers answer "Infrequent/Mild"; Apple then assigns the rating.
- Not in the Kids category. The Kids category requires parental gates on purchases and links, and the app is for parents and teens.

## Subscriptions (App Store Connect › Subscriptions)

| Reference name | Product ID | Duration | Family Sharing | Price |
|---|---|---|---|---|
| Premium Yearly | `app.linden.growth.premium.yearly` | 1 year | On | Your decision. $39.99 is a test value only. |
| Premium Monthly | `app.linden.growth.premium.monthly` | 1 month | On | Your decision. $5.99 is a test value only. |

- **Group:** "Linden Premium". Both plans are at the same level.
- **Display name / description for each:** "Linden Premium". "Doctor-ready reports, advanced analysis, family profiles and unlimited Ask Linden."
- **Review screenshot:** use `appstore-06.png` or a paywall capture.

## App Review notes (paste into "Notes")

> Linden needs no account or login. All data is stored on the device.
> To see Premium: open the Profile tab › Explore Premium, or tap "Generate report" in Profile › Doctor-ready report. Restore purchases is on the paywall and in Profile.
> Ask Linden (Home › Ask Linden) uses Apple's on-device Foundation Models framework on devices with Apple Intelligence. On other devices it answers with a built-in, deterministic guide. No data leaves the device. Questions about self-harm, eating disorders, emergencies or growth hormone/steroids/surgery get fixed safety answers (988, 911, see a pediatrician).
> The app gives growth-chart information (CDC 2000 references) and says it is not medical advice. The adult-height estimate is labelled as an estimate, never a guarantee.
> Reminders are local notifications, requested only when the user turns one on.

## Screenshots

CI composes six 1320 × 2868 screenshots (6.9-inch display) into the `store-screenshots` folder of the CI artifact. Upload them in order:

1. Growth, beautifully understood (Home)
2. See the whole growth story (Growth chart)
3. Ask Linden anything (assistant)
4. A doctor-ready report (report preview)
5. Small habits. No guilt. (Habits)
6. Go deeper with Premium (advanced analysis)

App Store Connect scales the 6.9-inch set for smaller iPhones.
