# Monetization Strategy

> Phase 1 deliverable. **No prices are fixed here.** Final price points are chosen in Phase 10 from storefront research and controlled tests. Competitor prices are reference observations only (see `competitor-research.md` §3, third-party sourced).

## 1. Principles

1. **The core prediction is free.** It is our wedge against the competitor's main complaint.
2. **Charge for ongoing value**, not for unlocking a number the user already "earned" with their answers.
3. **No dark patterns:** no fake countdown timers, no hidden or pre-selected trials, no confusing weekly framing of yearly prices without the full price shown just as prominently, an easy-to-find close button, and a renewal reminder before trials convert.
4. **Minors:** purchases go through Apple (Ask to Buy for Family Sharing children). Copy aimed at teens never uses pressure tactics. The parent is the main buyer persona.
5. **No ads, no selling data.** Ever.

## 2. Free vs Premium (proposed split)

| Feature | Free | Premium |
|---|---|---|
| Adult height estimate (range + methods) | ✅ | ✅ |
| Mid-parental target | ✅ | ✅ |
| Measurement log | ✅ unlimited | ✅ |
| Percentile chart (all points) + current velocity | ✅ | ✅ |
| Trend insights (spurt/plateau detection, history comparisons, "growth likely complete" explainer) (P2) | — | ✅ |
| Safety signposting | ✅ (**always free**; safety is never paywalled) | ✅ |
| Habit check-ins | ✅ basic | ✅ + plans, weekly review |
| Learn articles | Core set | ✅ full library |
| Profiles | 1 | Multiple (family) |
| Clinician PDF export (P2) | — | ✅ |
| AI Coach (P2, 13+) | A few messages to try (cap TBD) | Higher daily cap |
| Widgets / Health sync (P2) | Basic | ✅ advanced |
| Cloud backup & sync | ✅ (also a retention lever and a deletion/export obligation either way) | ✅ |

*Rationale:* free covers predict + track + safety. Premium covers depth, family, coach and export, which is where parents see recurring value.

## 3. Pricing model options (to test, not decided)

| Option | Pros | Cons | Fit |
|---|---|---|---|
| **A. Yearly + monthly subscription** | Predictable, matches monthly measuring cadence, standard | Monthly may churn after a growth spurt | **Lead candidate** |
| B. Weekly + yearly | Competitor pattern, high short-term ARPU | High refund/complaint risk, looks predatory toward teens | Not recommended |
| C. Lifetime one-time | Parents like it, simple, pairs well with honesty branding | Caps LTV. Coach has ongoing LLM cost (a lifetime plan would need a coach message cap) | Test as a secondary option |
| D. Family plan (Family Sharing enabled) | Matches the parent persona, a differentiator | Lower per-user revenue | Enable Family Sharing on the subscription |
| E. Freemium + one-off "report" IAP (PDF) | Low commitment | Small revenue | Possible add-on (P2) |

**Proposed launch set (for Phase 10 validation):** Premium Yearly (primary, optional short free trial) + Premium Monthly, with Family Sharing on. Lifetime decided after beta data. Price points are set per storefront using Apple's price tiers, informed by the competitor reference range (yearly offers observed from about $6 to $60 USD, third-party data) and our own positioning as a trustworthy premium product.

## 4. Paywall design rules

- **Triggers:** tapping a premium feature, one soft offer after the free result (dismissible with one tap, shown at most once per session), settings "Upgrade".
- **Content:** what you get (3–5 concrete benefits), full price per period in the primary text, trial length and the exact renewal date if a trial is offered, restore purchases, terms + privacy links, an "auto-renews, cancel anytime in Settings" line.
- **Never:** countdown timers that reset, "only X left", fake discounts against made-up anchors, testimonials we cannot verify, a close button hidden for seconds.
- **Trial reminder:** local notification 24 h before the trial converts (opt-in from the paywall).
- **Compliance check:** App Store Guideline 3.1.2 (auto-renewable subscription disclosures), plus regional rules (for example, EU consumer law on clear pricing, and US state auto-renewal laws such as California's).

## 5. Infrastructure

- **StoreKit 2 + RevenueCat** (receipt validation, entitlements, paywall experiments, webhooks to Supabase `entitlements`). See Tech Arch §6.
- Introductory offers / promo codes for referrals (P2) through App Store Offer Codes.
- Entitlement checks on the server for the coach. Client checks for UI only.

## 6. Referral program (P2)

- Reward: premium time for **both** inviter and invitee after the invitee's first measurement (not just an install), so the reward goes to real use.
- No contact list upload. Share link only. Disabled for under-13 profiles.
- Anti-abuse: a per-account reward cap and device-check heuristics.

## 7. Growth channels (organic-first, no paid UA needed at launch)

- Short-form video with **educational** angles (how growth plates work, myth-busting, "how to measure yourself correctly") made by us or vetted creators, with platform ad-disclosure rules followed. Never anxiety-bait ("are you going to be short?").
- ASO: keywords around height predictor, growth chart, child growth tracker, percentile. Avoid competitor trademarks in metadata.
- Parent channels: parenting blogs and newsletters, with a free web calculator page (P3) linking to the app.
- Share card (range only, opt-in).

## 8. Metrics and experiments

- Funnel: install → result → soft-offer view → trial start → paid → renewal. Refund rate and review sentiment.
- **Guardrail metrics** (an experiment fails if these regress): refund rate, 1-star reviews mentioning paywall/scam, support tickets, D30 retention.
- Experiments (Phase 10+): trial vs no trial, yearly price point, lifetime presence, free coach message cap.
- **No revenue projections in Phase 1:** there is no first-party data. The competitor's self-reported ~$100K/month is unaudited and comes from tactics we deliberately avoid, so it is not a baseline for us.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Free prediction lowers conversion vs the gated competitor | Premium value lives in tracking/family/export. Retention through monthly measuring |
| LLM cost per user exceeds revenue | Daily caps, small model, prompt caching, coach is premium-weighted |
| Teens can't pay | Parent persona, Family Sharing, Ask to Buy |
| Store rejection over subscription disclosures | Phase 10 checklist against Guideline 3.1.2 |
