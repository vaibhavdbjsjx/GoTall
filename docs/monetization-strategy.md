# Monetization Strategy (Phase 1.5)

> Supersedes the free/premium split and launch-tier proposal in `monetization.md` (Phase 1). Phase 1's principles (no dark patterns, no ads, no data sales) still apply. **No prices are fixed here.**

## 1. What users pay for

The prediction gets people in. **Parents pay for ongoing, organised, shareable tracking of their children.** Teens pay less often and mostly through a parent (Ask to Buy / Family Sharing). The MVP's paid value must therefore exist **without an AI coach**:

| Tier | Feature | Why here |
|---|---|---|
| **Free** | Adult-height scenario range + family-height range + Methods page | Trust wedge. Fixes the competitor's #1 complaint |
| Free | Current percentile, basic growth chart, current velocity number | Core usefulness. Lets a pediatrician-style chart be checked |
| Free | Measurement history (unlimited), measuring guide, reminders | Retention loop. Data belongs to the user |
| Free | Safety signposting | **Safety is never paywalled** |
| Free | Basic habit check-ins | Healthy-habit engagement |
| **Premium (MVP)** | **Multiple profiles (family)** | Main paid reason for parents |
| Premium (MVP) | **Doctor-ready PDF growth report** (chart, measurements, methods, disclaimer) | Concrete, rare, useful at check-ups |
| Premium (MVP) | **Advanced growth analytics:** percentile history, velocity history, "estimate stability" explainer, before/after comparison | Depth for engaged users |
| Premium (P1) | Habit plans + weekly review | Low cost, adds retention |
| Premium (P1) | AI coach (13+, capped) | Variable cost. Must be validated |
| ❌ Not built | Nutrition photo analysis, personalised "growth plans" that imply cm gains | Scientific/safety reasons (see `mvp-scope.md`) |

## 2. Plan structure options

| Option | Verdict | Reason |
|---|---|---|
| Monthly | ✅ Launch | Low commitment. Shows real retention |
| Yearly | ✅ Launch (primary) | Matches monthly measuring over a growth year |
| Free trial | 🧪 Test | Trial vs no-trial is the first experiment. If a trial is offered: a short trial with a renewal reminder |
| Introductory offer (discounted first period) | 🧪 Test later | An alternative to a trial |
| Family plan | ✅ Enable **Family Sharing** on subscriptions | Profiles live on one device anyway. Family Sharing lets a teen's own device unlock |
| Lifetime | ⏸ Not at launch (see §4) | Cost/LTV analysis needed |
| Weekly | ❌ | Predatory perception with teens. Refund risk |

## 3. Pricing experiment framework

### 3.1 Unit economics model (fill in with real data. No placeholders are presented as forecasts)

```
net_price(plan, storefront)   = gross_price × (1 − commission) − VAT/GST (Apple handles tax. Proceeds are shown net)
commission                    = 15% if enrolled in App Store Small Business Program (≤ $1M proceeds prior year),
                                else 30% in a subscriber's first paid year, 15% after
cost_per_premium_user_month   = backend_cost/MAU + ai_messages × ai_cost_per_message + support_cost
contribution_month            = net_price_monthly_equivalent − cost_per_premium_user_month
LTV_subscription              = Σ_t contribution_month × retention(t)
LTV_lifetime                  = net_lifetime_price − Σ_t cost_per_premium_user_month × activity(t)
CAC (organic-first)           = content production cost / attributable paying users
```

**Inputs to measure, not guess:** paywall view → purchase conversion, trial → paid, monthly churn, yearly renewal, refund rate, AI messages per premium user, backend cost/MAU.

**MVP architecture note:** with a local-first MVP (CloudKit private database, no server), **backend cost per user is close to zero** and there is **no AI cost**. Contribution ≈ net price. AI (P1) is the first variable cost and must be capped per user.

### 3.2 Experiment sequence
| Stage | Question | Method | Guardrails |
|---|---|---|---|
| 0 Beta | What do parents consider fair? | Van Westendorp price-sensitivity survey + interviews with TestFlight parents (adults only) | — |
| 1 Launch | Baseline | One monthly + one yearly price (chosen from stage 0 and positioning), no trial | Refund rate, 1★ "paywall" reviews |
| 2 | Trial vs no trial | RevenueCat Experiments (adopted in P1) or sequential periods | Trial→paid, refunds |
| 3 | Yearly price point | 2–3 price levels, one at a time | Conversion × price = revenue/user |
| 4 | Lifetime "Core" | Add lifetime excluding AI (§4) | Cannibalisation of yearly |
| 5 | Regional pricing | When new storefronts open (e.g., India): local price points, not FX conversion | Conversion per storefront |

**Decision rule:** keep a variant only if revenue per paywall viewer improves **and** no guardrail gets worse beyond a pre-set tolerance. Decide sample sizes before each test (power calculation) and do not stop tests early.

### 3.3 Price-setting inputs
- Competitor observations (third-party, unverified): yearly offers seen from about $6 to $60 and weekly $0.99–$14.99 (see `competitor-research.md`). **Reference only. Not copied.**
- Positioning: trustworthy, premium, parent-oriented. Avoid both "cheap clone" and "anxiety premium".
- Storefront: US at launch (see `launch-strategy.md`).

## 4. Does lifetime make sense?

- **MVP (no AI, local-first):** marginal cost per user ≈ 0, so a lifetime plan is economically safe **for the non-AI feature set**.
- **With AI coach (P1):** every active lifetime user keeps creating token cost with no new revenue. An unlimited lifetime plan with AI has **unbounded liability**.
- **Recommendation:** no lifetime at launch (keeps the yearly baseline clean). Later test **"Lifetime Core"**, which includes family/reports/analytics and **excludes AI**. AI then becomes a separate monthly add-on or a capped monthly allowance. Lifetime price should be at least `k × net yearly price`, where k is the expected number of paid years for yearly subscribers measured from cohort data (k unknown until measured).

## 5. Compliance checklist (for Phase 10)
- Guideline 3.1.2: price, period, auto-renewal terms, cancellation info, links to terms/privacy on the paywall.
- No fake urgency, no hidden close button, no pre-selected trial.
- Restore purchases visible.
- Enrol in the Small Business Program before the first sale.
- Texas/Utah-style app store acts: purchases by minors may need parental consent handled by the store. Use Apple's signals and do not build our own payment flows.

## 6. Infrastructure decision
- **MVP: StoreKit 2 only** (on-device entitlement check through `Transaction.currentEntitlements`). No server needed, fewer SDKs, no third-party data flow.
- **P1:** add RevenueCat (or the App Store Server API) when experiments and the AI entitlement check on a server are needed.
- *Phase 1 is corrected:* `technical-architecture.md` had RevenueCat + Supabase in the MVP. Both now move to P1.
