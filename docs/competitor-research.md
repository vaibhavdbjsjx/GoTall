# Competitor Research: "GoTall – Height Predictor" (Grow Labs LLC)

> Phase 1 deliverable. Status: research only. No code, assets, copy, or UI from the competitor were used or will be used.
> Research date: 2026-10-07.

## 0. Method and limits (read first)

- **Sources:** web search result extracts from the App Store listing (`apps.apple.com/us/app/id6747467975`), app-tracking sites (AppFollow, mwm.ai, AppBrain, apppricinglab), a UI teardown site (screensdesign.com), founder interviews (sofarbot, stork.ai, BigGo Finance, woshipm), and the developer sites (`gotall.app/support`, `growlabsllc.com`).
- **Limit:** this cloud environment's network policy **blocks direct fetches** of `apps.apple.com`, `apppricinglab.com`, `screensdesign.com` and similar sites. Everything below comes from search-engine extracts of those pages, not from pages I loaded myself. Every claim has a confidence tag:
  - **[O]** Observed: an extract quotes the store listing or the developer's own text.
  - **[3P]** Third-party report: aggregator, teardown or press. Plausible but not confirmed with the developer.
  - **[I]** Inferred: my reasoning from the above. Not a fact about the competitor.
  - **[NV]** Not verified: no data found. **Must be checked by hand** on a real iPhone before Phase 2 decisions that depend on it.
- **I could not read** the full privacy policy text, the terms of service, the full version history or the screenshots. Section 7 lists what to check by hand.

## 1. Snapshot

| Field | Value | Tag |
|---|---|---|
| App name | GoTall – Height Predictor | [O] |
| App Store ID | 6747467975 | [O] |
| Seller / developer | Grow Labs LLC | [O] |
| Category | Health & Fitness | [O] |
| Price model | Free download with in-app purchases (subscriptions + lifetime) | [O] |
| Rating | 4.6★, about 6.8K ratings (one extract says 6,776) | [O] |
| Size | 132.1 MB | [O] |
| Minimum OS | iOS / iPadOS 15.4 | [O] |
| Age rating | Conflicting extracts (9+ was mentioned). **[NV]** | [NV] |
| Languages | English confirmed. Full list **[NV]** | [O]/[NV] |
| Platforms | iOS/iPadOS. Separate Android listing `app.gotall.play`. Web account/subscription flows mentioned in release notes (v11.3.1) | [O] |
| Latest versions seen | v14.1 (Sept 5): quicker start after setup, Nutrition + Coach improvements, smoother invites/account handling. v14 (Aug 5): Habits, Nutrition, Coach, growth resources, profile setup. Version 12.0.0 also listed on download mirrors | [O] |
| US category rank | "Outside top 30 Free Health & Fitness" at the time of the extract | [3P] |
| Revenue | Founder **self-reports** about $100K/month | [3P] (unaudited) |

**Copycats and adjacent apps** seen in the same searches: "Height Predictor – goTall" (id6754962274, a different developer), "GoTaller – Height Predictor" (iOS id6753605862 and Android `com.bilgecakirlar.growmaxx`), "goTall – AI Height Predictor" (Android, `com.puranjanics.gotallai`). The niche is crowded with clones, which means names close to "GoTall" carry trademark and ASO confusion risk. **We must not use "Tall/GoTall" in our name** (see PRD §2).

## 2. Positioning and claims (paraphrased, not copied)

- Says it is the "most accurate" height predictor and leans into "heightmaxxing" culture. [O]
- Says it uses CDC data and asks for parent/relative heights, sleep, food, activity and puberty stage. [O]
- Sells a "custom growth plan" with daily exercises framed as supporting posture, bone strength and "natural growth hormone (HGH) activity", plus nutrition analysis and lifestyle tracking. [O]
- **Our view [I]:** "most accurate" with no published method or validation, and implied links between exercises/diet and HGH or added height, are exactly the claims App Store Guideline 1.4.1 scrutinizes. They also raise consumer-protection risk (deceptive-claims rules, for example FTC Act §5 in the US). This is both the competitor's biggest weakness and our clearest opening: **honesty as a feature.**

## 3. Growth and monetization model (as reported)

- **Acquisition [3P]:** organic TikTok. The founder replied to comments where teens posted their age, height and parents' heights asking for predictions, then hired UGC creators to copy the format. Reported CAC was about $0.03. The market signal is strong: teens actively ask for this.
- **Onboarding [3P]:** about 31 steps, including a puberty quiz (5–10 questions with linked studies). Then a "building your plan" moment and a paywall shown to about 91% of users.
- **Paywall [3P]:** free trial with a soft paywall. A **3-minute countdown timer**, yearly price framed as a small weekly amount, testimonial + star rating, and a 3-day trial that converts to yearly. The prediction result itself is reportedly **locked behind the subscription.**
- **Observed in-app purchase price points [3P, from IAP lists aggregated by third parties; exact live offers vary by user/experiment and were NOT confirmed on a device]:**

| Product type | Price points listed (USD) |
|---|---|
| Weekly | $0.99, $3.99, $4.99, $5.99, $9.99, $14.99 |
| Monthly | $0.99, $11.99 |
| Yearly | $5.99, $9.99, $13.90, $19.99, $29.99, $34.99, $39.99, $59.99 |
| Lifetime | $29.99, $59.99 |

  The many price points across tiers strongly suggest paywall A/B testing and/or win-back and discount offers. [I]
- **Referral [O/3P]:** "invite 3 friends → 1 year Premium".
- **User complaints [3P]:** a large group of reviews complain that after a long personal questionnaire the result is withheld unless you subscribe. This is the main sentiment pattern behind the otherwise high 4.6★.

## 4. Privacy and data (as reported)

- **iOS privacy label [O via extract]:** "Data Used to Track You: Usage Data", "Data Linked to You: Usage Data", "Data Not Linked to You: Diagnostics". [I] Tracking usage data on an app aimed mostly at teenagers is a privacy weakness, and on iOS it requires the ATT prompt.
- **Android Data Safety [O via extract]:** collects location, personal info and other data. "Data cannot be deleted" was stated. If accurate, that is a weak point under GDPR/CCPA and for Google Play's deletion rules.
- Privacy policy and ToS full text: **[NV]**. Check by hand for: minimum age, parental consent wording, AI provider disclosure, retention periods and a deletion path.

## 5. Competitor Feature Matrix (46 feature areas)

Legend: Tags as in §0. Priority = our build priority: **MVP**, **P2** (fast follow, within about 3 months of launch), **P3** (later or only if validated).

| # | Feature | Competitor implementation | Why it matters | Weakness / opportunity | Our proposed implementation | Priority |
|---|---|---|---|---|---|---|
| 1 | Adult height prediction | Core feature. Quiz-based, "most accurate", CDC-referenced [O] | The job users come for | Method undisclosed, result paywalled [3P] | Free prediction as a **range** with methods shown (Engines A/B, see Tech Arch §5) | MVP |
| 2 | Mid-parental height | Asks parents' heights [O] | Biggest single genetic signal | Unknown formula | Tanner mid-parental target ± commonly cited range, shown as its own card | MVP |
| 3 | Relative heights (siblings, grandparents) | Asks relatives [O] | Feels personal | Little evidence of extra accuracy beyond the parents [I] | Collect optionally for context only. Not in the core formula unless validated | P3 |
| 4 | Puberty stage input | Puberty quiz with study links [3P] | Timing drives remaining growth | Intimate questions to minors, risky [I] | Age-appropriate self-check limited to non-intimate signs (for example, growth spurt timing, voice change, first period yes/no), with a skip option. No body photos ever | P2 |
| 5 | Percentile / growth charts | **[NV]** | Clinically standard view | Opportunity if absent | CDC 2–20 stature-for-age percentile chart with the user's points | MVP |
| 6 | Height logging over time | Implied by monthly updates [3P] | Retention and trend | **[NV]** depth | Fast log with date, time of day and a measurement-method note | MVP |
| 7 | Growth velocity (cm/yr) | **[NV]** | Spurt detection | Opportunity | Velocity from ≥2 measurements at least 3 months apart, with noise warnings | MVP |
| 8 | Growth-spurt detection / phase | **[NV]** | Engaging and informative | Opportunity | Descriptive "trend" card (Engine C). Never moves the predicted range on its own without data | P2 |
| 9 | Measurement guide | **[NV]** | Bad input = bad output | Opportunity | Illustrated wall-measure guide, "measure in the morning" tip, repeat-3-times average | MVP |
| 10 | Camera/AR height measuring | Not seen | Novelty | Accuracy cannot be validated, Guideline 1.4.1 risk | **Do not build** unless validated. At most an AR "assist" with an accuracy disclaimer | P3 |
| 11 | Personalized growth plan | Core paid feature [O] | Paid value, retention | Framed as raising height/HGH, misleading [I] | "Healthy growth habits" plan (sleep, nutrition, activity, posture) framed as health and **not adding cm** | MVP |
| 12 | Exercises / stretches | Daily exercises, stretch heatmaps [O] | Daily engagement | Claims to affect HGH/bones [O] | Posture and mobility routines from public guidance. Original illustrations. No height claims | P2 |
| 13 | Posture content | Mentioned [O] | Posture can change *measured standing height* slightly | Can be over-promised | Honest copy: "standing tall can change how tall you measure, not your bones" | P2 |
| 14 | Nutrition analysis | AI meal analysis [O] | Paid hook | Calorie/macro tracking for teens risks disordered eating [I] | Food-group checklist (protein, calcium, vitamin D sources). **No calorie counting for minors** | P2 |
| 15 | AI meal camera | "AI Camera" to add meals [3P] | Wow factor | Accuracy, cost, ED risk | Defer. If built: food-group recognition only, adults/parents, no calories for minors | P3 |
| 16 | Meal recommendations | "Based on what your body still needs" [O] | Personalization | Nutrient-gap claims need validation | Simple, sourced suggestions (for example, calcium sources). No deficiency claims | P3 |
| 17 | Sleep tracking | Lifestyle tracking [O] | Sleep matters for health | Unknown | Manual bedtime/wake log + optional Apple Health sleep read | P2 |
| 18 | Activity tracking | Lifestyle tracking [O] | Health | Unknown | Optional Apple Health steps/workouts read | P2 |
| 19 | Habit tracker | Habits tab, streaks [O] | Retention | Gamified "growth" streak implies cm gains [I] | Habit check-ins (sleep, activity, nutrition, posture) with gentle streaks and **no** cm framing | MVP |
| 20 | Streaks / XP / badges | XP, streaks, badges [O] | Retention | Streak anxiety | Forgiving streaks (freeze days), non-punitive copy | P2 |
| 21 | AI coach chat | "Height Coach" with memory [O] | Paid value | Medical-adjacent advice to minors, hallucination risk | Scoped, safety-filtered coach. Server-side LLM. Grounded on our content. Never predicts height. Escalates to doctor. 13+ only | P2 |
| 22 | Coach memory | Remembers conversations [O] | Personalization | Privacy for minors | Opt-in, viewable and deletable memory summary, minimal retention | P2 |
| 23 | Monthly plan updates | Plan adjusts on progress [O] | Retention | Unknown logic | Weekly review: habit adherence summary + new measurement reminder | P2 |
| 24 | Educational content library | "Growth resources" [O] | Trust, SEO, ASO | Possibly pseudo-scientific | Short evidence-based articles with citations (CDC, WHO, AAP, NHS), medically reviewed before launch | MVP (5–10 articles) |
| 25 | Research citations | Study links in quiz [3P] | Credibility | May be used to over-claim | Citations explain limits too. Methods page | MVP |
| 26 | Onboarding length | ~31 steps [3P] | Investment drives conversion | Abuse: long quiz then hard gate → complaints [3P] | ≤12 required steps to a free result. Optional deeper profile later | MVP |
| 27 | Paywall placement | After quiz, before result, ~91% show rate [3P] | Revenue | Main source of negative reviews | Result free. Paywall shown on premium features + one soft offer after the result | MVP |
| 28 | Paywall tactics | Countdown timer, weekly framing, testimonials [3P] | Conversion | Dark-pattern risk, scrutiny for minors | **No fake timers, no pre-checked trials**, plain renewal terms (see Monetization §4) | MVP |
| 29 | Free trial | 3-day trial → yearly [3P] | Conversion | Surprise charges for teens | Trial optional, with a reminder notification before renewal | MVP |
| 30 | Pricing tiers | Weekly/monthly/yearly/lifetime, many price points [3P] | Revenue tests | Confusing | Small tier set. Prices set in Phase 10 via tests | MVP |
| 31 | Referral program | Invite 3 → 1 year free [O] | Viral loop | Invites between minors, spam risk | Invite with a single-use link. Reward = premium time for both. No contact upload | P2 |
| 32 | Share card | **[NV]** (TikTok-driven growth implies sharing) [I] | Organic growth | Sharing minors' data | Shareable image showing *range only*, no name/age by default | MVP |
| 33 | Account / sign-in | Accounts, web account flows [O] | Sync, web billing | Unknown requirements | Sign in with Apple (+ email optional). Usable locally without an account | MVP |
| 34 | Web subscription / web app | Web account and subscription management [O] | Lower fees outside the store | Steering and minor-payment issues | Not at launch. Re-evaluate under current store rules | P3 |
| 35 | Parent / family mode | **[NV]** | Parents pay. Under-13 compliance | Big opening if absent | Parent account with multiple child profiles. Parent controls AI/coach, sharing, deletion | MVP (basic) / P2 (full) |
| 36 | Multiple profiles | **[NV]** | Siblings | Opening | Up to N child profiles under a parent account | MVP |
| 37 | Clinician export (PDF) | **[NV]** | Trust, real utility | Opening | PDF of measurements + CDC chart + method notes "for your doctor" | P2 |
| 38 | Apple Health integration | **[NV]** | Native feel, less input | Opening | Read/write height (opt-in), read sleep/steps | P2 |
| 39 | Widgets / Live Activities | **[NV]** | Retention | Opening | Home-screen widget: next measurement date, habit progress | P2 |
| 40 | Notifications | Implied [I] | Retention | Spam | Measurement reminders (monthly), habit nudges, quiet hours. Teen-safe copy | MVP |
| 41 | Unit support (cm / ft-in) | **[NV]** | Global | Basic | Both, auto from locale, switchable | MVP |
| 42 | Localization | English seen [O] | Market size | Opening | EN at launch. ES, PT-BR, DE, FR, HI next (validated by ASO data) | P2 |
| 43 | Privacy / tracking | Usage data used for tracking [O] | Trust, ATT prompt | Weakness in a teen app | **No cross-app tracking**. First-party privacy-preserving analytics only. No ATT prompt needed | MVP |
| 44 | Data deletion | Android: "data cannot be deleted" [O] | Legal + store requirement | Weakness | In-app account + data deletion, export, retention policy | MVP |
| 45 | Community / UGC | Not observed in-app (UGC is a *marketing* channel) [3P] | Engagement | Moderation burden, risk for minors | No open community at launch. Possibly curated challenges later | P3 |
| 46 | Medical safety signposting | **[NV]** | Safety, store review | Opening | Red-flag rules (for example, very low percentile, crossing ≥2 major percentile lines, velocity stall) → "talk to a pediatrician" card, no diagnosis | MVP |

## 6. Key takeaways

1. **Demand is real and organic** (teens asking in comments). Distribution through short-form video with honest, educational content is viable for us too, without the anxiety-bait.
2. **The competitor's revenue engine depends on tactics with growing regulatory and review risk:** gated result after a long quiz, countdown timer, HGH/height-gain implications, tracking in a teen-heavy app.
3. **Our wedge:** free honest prediction with ranges → trust → retention through tracking (measurements, percentiles, velocity) → premium for depth (family, coach, exports, insights). Parents are the paying segment and are underserved.
4. **Avoid at all costs:** claims that habits add centimeters, body photos, calorie counting for minors, open DMs between minors.

## 7. Manual verification checklist (before Phase 2 sign-off)

Install the competitor on a test device (US storefront), do not subscribe, and record:
- [ ] Current paywall offers and prices shown (screenshots kept privately for internal reference only, never in our repo or marketing)
- [ ] Exact onboarding step count; whether any result is shown before the paywall
- [ ] Age rating, languages, full privacy label
- [ ] Privacy policy + ToS: minimum age, consent, AI vendor, retention, deletion route
- [ ] Whether percentile charts, parent mode, multi-profile, Health integration, widgets, exports exist
- [ ] Full version history (last 12 months)

## Sources

- App Store listing (via search extracts): https://apps.apple.com/us/app/gotall-height-predictor/id6747467975
- AppFollow: https://apps.appfollow.io/ios/gotall-height-predictor/6747467975?country=us
- mwm.ai: https://mwm.ai/apps/gotall-height-predictor/6747467975
- App Pricing Lab: https://apppricinglab.com/app/apple/6747467975
- Screens Design teardown: https://screensdesign.com/showcase/gotall-height-predictor
- Sofarbot story: https://www.sofarbot.com/stories/gotall-michael-100000-monthly-ai-height-app
- Stork.ai: https://www.stork.ai/blog/this-students-dumb-app-makes-100kmo
- BigGo Finance: https://finance.biggo.com/news/afe5741b54c2d24b
- marlvel.ai review: https://marlvel.ai/apps/gotall-height-predictor
- Developer: https://growlabsllc.com/ , https://www.gotall.app/support
- Google Play: https://play.google.com/store/apps/details?id=app.gotall.play
- Comparison page (competitor-authored, biased): https://gotaller.app/best-height-predictor-apps
