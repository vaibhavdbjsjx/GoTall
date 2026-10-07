# Manual Competitor Checklist: GoTall (real iPhone)

> **Status: NOT PERFORMED.** Nothing in this file is verified until the developer fills it in. Results stay internal. Screenshots are kept **outside the repository** (private folder), are never used in our design or marketing, and are used only to record facts.

## Before you start (privacy and cost safety)
- Use **fictional data** for every question (for example, invented age, heights, name "Test"). Never enter real information about yourself or a child.
- Use a **US storefront** Apple ID if possible (prices differ by country). Write down the storefront used.
- Turn **Ask App Not to Track** on if the ATT prompt appears, and record that it appeared.
- **Do not subscribe** unless you decided to test the trial. If you do: note the exact price/terms, then cancel straight away in Settings → Apple ID → Subscriptions, and record the cancellation path. Record any charge.
- Don't sign in with your primary email. Use "Hide My Email" if sign-in is required.
- Record: date, app version (App Store → version history), iOS version, device.

## How to fill in
For each row: **Observed?** = Yes / No / Not found. **Screenshot?** = what to capture. Write findings in the "What to record" column of your copy.

| # | Area | Observed? | Screenshot needed? | What to record | Why it matters |
|---|---|---|---|---|---|
| 1 | App Store listing | ☐ | Yes: listing top, privacy label, IAP list, age rating | Version, date, rating/count, age rating, languages, size, full "In-App Purchases" list with prices, privacy label categories | Confirms the third-party data in `competitor-research.md` |
| 2 | First launch / ATT | ☐ | Yes: any permission prompt | Order of prompts (ATT, notifications), timing | Privacy posture. Our "no tracking" contrast |
| 3 | Onboarding screen sequence | ☐ | Yes: every screen (or a screen recording) | Count of screens to first value. Which are skippable. Progress indicator | Tests the "≈31 steps" report. Shapes our ≤10-step goal |
| 4 | Questions asked | ☐ | Yes | Exact list: age, sex, height, weight, parents', relatives', **ethnicity (yes/no?)**, puberty questions (wording, how intimate), sleep, diet, activity, goals | Data minimization comparison. Ethnicity decision context |
| 5 | Puberty quiz | ☐ | Yes | Number of questions, wording, whether studies are linked, any body-related questions | Safety comparison for minors |
| 6 | Paywall placement | ☐ | Yes | When it appears (before/after result). Can it be closed? How long until close is visible? Countdown timer? | Core differentiation (free result) |
| 7 | Prediction reveal | ☐ | Yes | Is any number shown free? A single number or a range? Any accuracy claim? Method explanation? | Honesty contrast. Guideline 1.4.1 |
| 8 | Free vs premium boundary | ☐ | Yes: each locked screen | Which features are usable without paying | Our free/premium design |
| 9 | Pricing displayed | ☐ | Yes | Every price shown, the plan names, weekly framing, "% off" anchors, offer changes after dismissal (win-back) | Price research (reference only) |
| 10 | Subscription options | ☐ | Yes | Weekly/monthly/yearly/lifetime availability, default selection | Plan structure comparison |
| 11 | Free trial | ☐ | Yes | Length, default toggle state, renewal disclosure wording, reminder offered? | Dark-pattern check |
| 12 | Restore purchases | ☐ | Yes | Location and visibility | Guideline compliance benchmark |
| 13 | Home screen | ☐ | Yes | Layout elements, primary call to action, streaks, daily tasks | Engagement model (don't copy UI) |
| 14 | Prediction screen | ☐ | Yes | Displayed fields, how updates happen, disclaimers | Benchmark vs our result contract |
| 15 | Growth chart | ☐ | Yes | Does a percentile chart exist? Which reference is named? Velocity shown? | Our differentiator #2 check |
| 16 | Habits | ☐ | Yes | Habit types, XP/badges, any cm/HGH claims tied to habits | Claims risk. Lifestyle-engine contrast |
| 17 | Sleep | ☐ | Yes | Manual or Health-based, targets, claims | Feature depth |
| 18 | Nutrition | ☐ | Yes | Photo analysis? Calories shown to minors? Claims about growth | Safety contrast (no calories for minors) |
| 19 | Exercise | ☐ | Yes | Library size, claims (posture, "grow taller", HGH) | Claims risk |
| 20 | Coach (AI) | ☐ | Yes | Free or paid, disclaimers, behaviour on a medical question (ask: "Should I take growth supplements?"). Never enter real data | AI safety benchmark |
| 21 | Profile | ☐ | Yes | Fields, multiple profiles, parent mode? | Family-mode gap check |
| 22 | Account | ☐ | Yes | Sign-in methods, required or optional, web account mention | Account model comparison |
| 23 | Privacy controls | ☐ | Yes | Privacy settings, links to policy/ToS, data export option | Trust comparison |
| 24 | Deletion | ☐ | Yes | In-app account deletion present? Steps count? (**Don't complete** if it would affect anything real. Just record the path) | Guideline 5.1.1(v) benchmark |
| 25 | Referral | ☐ | Yes | Offer terms (e.g., "invite 3 → 1 year"), mechanism (link vs contacts) | Growth loop + minors risk |
| 26 | Notifications | ☐ | Note only | Permission timing, frequency over 3 days, tone | Retention vs spam comparison |
| 27 | Widgets | ☐ | Yes, if any | Widget types available | P2 scope relevance |
| 28 | Community | ☐ | Yes, if any | Any feed, chat, leaderboards, DMs, moderation/reporting tools | Minors' safety risk benchmark |
| 29 | Privacy policy & ToS (web) | ☐ | Save PDF privately | Minimum age, parental consent, AI vendor named, retention, deletion route, data sharing | Compliance comparison |
| 30 | Version history | ☐ | Yes | Last 12 months of release notes (dates + themes) | Product velocity and roadmap signals |

## After the test
- Summarise findings in a short table (feature → observed fact) and update `competitor-research.md`, changing tags from [3P]/[NV] to [O] **only for items you personally observed**, with the test date.
- Delete any test account you created through the app's own deletion flow, if one exists, and record whether it worked.
