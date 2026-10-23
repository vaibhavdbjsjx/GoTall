# App Store listing: Gromax (v1.0.0)

Ready-to-paste metadata for App Store Connect. The character limits are Apple's. Check the name in App Store Connect before you rely on it (see `release-checklist.md`).

## Identity

| Field | Value | Notes |
|---|---|---|
| App name (30) | **Gromax: Height & Posture** | 25 characters |
| Subtitle (30) | **Growth chart & posture coach** | 29 characters. Keep "kids" out of the subtitle so it doesn't read as a Kids-category app. |
| Bundle ID | `com.vaibhavsg.gromax` | Must match App Store Connect |
| SKU | `stature-ios-001` | Any unique string |
| Primary category | Health & Fitness | |
| Secondary category | Lifestyle | Avoid Medical: it brings closer review and the app makes no medical claims. |
| Price | Free with in-app purchases | |

## Keywords (100, comma-separated, no spaces after commas)

```
height,predictor,growth chart,percentile,posture,stretch,kids,teen,tracker,puberty,sleep,child
```
Don't add competitor names, agency names (CDC) or "taller": they invite 1.4.1 / 5.2 questions.

## Promotional text (170, editable any time)

> Real CDC growth charts, an honest adult-height estimate, guided posture routines and a 30-second camera posture check. Private on your iPhone.

## Description (4000)

> Gromax helps teens, parents and adults understand growth honestly and build the habits that help you stand tall.
>
> REAL GROWTH CHARTS
> • Height percentiles from the CDC 2000 growth charts, explained in plain words
> • A clear chart with your measurements over the percentile curves
> • Growth speed from measurements months apart, the way clinicians read it
>
> AN HONEST ADULT-HEIGHT ESTIMATE
> • See where height would land if growth stays in its current percentile channel, with the reasoning behind it
> • A range, never a guarantee, with puberty timing and measuring differences explained
> • Family-height context from both parents' heights
>
> YOUR DAILY PLAN
> • A short plan every day: one routine, your habits, food variety and bedtime
> • Levels, points and a forgiving streak that never shames a missed day
>
> GUIDED ROUTINES
> • Posture, mobility, core, morning, evening and desk-break routines with a timer, cues and haptics
> • Built to help you stand at your full height and feel good. No exercise changes bone length, and Gromax never pretends it does.
>
> 30-SECOND POSTURE CHECK
> • Stand in front of your iPhone and get a score for head, shoulder and hip alignment, front or side
> • Analysed on your iPhone. No photo or video is saved or sent.
> • Routines picked for what the check found
>
> SLEEP, FOOD AND PUBERTY
> • Bedtime planner that works back from wake-up time, with the sleep range for your age and a wind-down reminder
> • Food-variety check-ins across six food groups
> • A private puberty-stage check that explains what it means for growth
>
> FOR PARENTS
> • Track several children in one place
> • Outgrow Forecast: expected height and clothing size over the next 3, 6 and 12 months
> • Doctor visit kit: questions to ask and a doctor-ready PDF report
>
> GROMAX COACH
> • Ask questions about growth, sleep, food, posture or measuring; answered on your iPhone using your own data
> • Careful by design: no invented numbers, no medical claims, no "grow taller" tricks
>
> PRIVATE BY DESIGN
> • No ads, no tracking, no account needed. Your data stays on your iPhone.
>
> GROMAX PRO
> All routines, weekly posture checks, the Outgrow Forecast, doctor-ready reports, advanced growth analysis, family profiles, the full Learn library and unlimited Gromax Coach. Your growth result, chart, estimate, history, habits and starter routines are always free.
> Choose monthly, or yearly with a 3-day free trial. Payment is charged to your Apple Account. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple Account › Subscriptions.
>
> Gromax provides information, not medical advice, and does not diagnose any condition. Talk to a doctor about any health concern.
>
> Privacy Policy: https://gromax-app.netlify.app/privacy
> Terms of Use: https://gromax-app.netlify.app/terms

## What's New (v1.0.0)

> Welcome to Gromax. Real growth charts, an honest estimate, a daily plan, guided routines and a private posture check.

## URLs

| Field | URL |
|---|---|
| Privacy Policy URL | https://gromax-app.netlify.app/privacy |
| Support URL | https://gromax-app.netlify.app/support |
| Marketing URL | https://gromax-app.netlify.app/ |

The marketing site lives in the project's `website/stature-site` folder and deploys to Netlify. `site/` in this repo holds the same legal text generated from the app (`scripts/build_site.py`); copy `site/privacy.html` and `site/terms.html` into the Netlify site whenever the policy changes, or the in-app and web text will differ.

## App Privacy ("nutrition label")

If you ship with accounts turned on (`STATURE_BACKEND_URL` set):
- **Data collected:** Contact Info › Email Address; Health & Fitness › Health (height measurements in the backup).
- For both: **Linked to the user: Yes. Used for tracking: No. Purpose: App Functionality** only.
- **Camera:** not collected (frames are processed on device and discarded).
If you ship without accounts, select "Data Not Collected" and remove the two entries from `App/Resources/PrivacyInfo.xcprivacy`.

## Age rating questionnaire (guidance)

- No violence, mature themes, gambling, user-generated content, web browsing or messaging.
- "Medical or treatment information": general growth-chart and wellness information, no treatment advice. Answer "Infrequent/Mild".
- Not in the Kids category (it requires parental gates; the app is for parents, teens and adults).

## In-app purchases (App Store Connect)

Prices are set a little under the original GoTall's. The app always shows the live App Store price.

| Reference name | Product ID | Type | Duration | Price (USD) | Notes |
|---|---|---|---|---|---|
| Gromax Pro Yearly | `com.vaibhavsg.gromax.pro.yearly` | Auto-renewable | 1 year | $34.99 | Introductory offer: 3-day free trial |
| Gromax Pro Monthly | `com.vaibhavsg.gromax.pro.monthly` | Auto-renewable | 1 month | $9.99 | |
| Gromax Pro Weekly | `com.vaibhavsg.gromax.pro.weekly` | Auto-renewable | 1 week | $4.99 | Not offered at launch (the app hides plans App Store Connect doesn't return) |
| Gromax Pro Lifetime | `com.vaibhavsg.gromax.pro.lifetime` | Non-consumable | — | $49.99 | Not offered at launch |

- **Subscription group:** "Gromax Pro". All three plans at the same level. Family Sharing on.
- **Display name:** "Gromax Pro". **Description:** "All routines, posture checks, forecasts and reports."
- **Review screenshot:** a capture of the paywall (CI screenshot `light-26-paywall` or similar).

## App Review notes (paste into "Notes")

> No login or account: everything is stored on the device. Onboarding takes about a minute (pick who you're tracking, birth date, a height).
> To see Gromax Pro: Profile › Explore Gromax Pro, or tap a locked routine on the Plan tab. Restore purchases is on the paywall and in Profile.
> The posture check (Plan › Posture check) uses the front camera with Apple's Vision framework on device. Nothing is recorded or uploaded.
> Gromax Coach uses Apple's on-device Foundation Models framework where available and a built-in deterministic guide elsewhere. No data leaves the device. Safety topics get fixed answers.
> Routines are posture and mobility exercises. The app states clearly that they don't change bone length. The adult-height estimate is labelled as an estimate, never a guarantee.

## Screenshots

CI composes 1320 × 2868 screenshots (6.9-inch) into `store-screenshots` in the CI artifact. Suggested order: Home with today's plan, growth chart, Plan tab with routines, posture check result, Outgrow Forecast, paywall.
