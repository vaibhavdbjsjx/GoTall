"""Generates the static pages for the Gromax marketing site.

Edit the brand settings below, then run:  python3 build/build.py
The generated .html files at the site root are what Netlify serves.
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from icons import I

OUT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---- Brand settings ----
APP = "Gromax"
STORE_NAME = "Gromax: Height & Posture"  # App Store name, from the app listing
# Support email: the one address shown across the site. Change it here and rebuild.
EMAIL = "gromax.support@gmail.com"
PRIVACY_EMAIL = EMAIL          # set a separate address here if you want one for privacy requests
COMPANY = "Gromax"            # developer / legal entity name shown on the App Store
STORE_URL = "#download"        # replace with the App Store link once the app is live
TRIAL = "3-day"
EFFECTIVE = "21 October 2026"  # effective date of the privacy policy and terms, matching the app

# Prices: keep in sync with App Store Connect
WEEKLY = "$1.99"
MONTHLY = "$4.99"
YEARLY = "$19.99"
YEARLY_PER_WEEK = "$0.38"
LIFETIME = "$29.99"

GOLD = "#e8c77a"
MARK = f'''<svg class="brand-mark" viewBox="0 0 32 32" aria-hidden="true"><rect width="32" height="32" rx="9" fill="{GOLD}"/><path d="M10 23h3V15h-3zM14.5 23h3V11h-3zM19 23h3V7h-3z" fill="#1a1408"/></svg>'''

C = I["check"]


def store_btn():
    return f'''<a class="store-btn" href="{STORE_URL}" aria-label="Download {APP} on the App Store">{I["apple"]}<span><small>Download on the</small><strong>App Store</strong></span></a>'''


def page(fname, title, desc, body, current=""):
    links = [("index.html", "Home"), ("features.html", "Features"), ("pricing.html", "Pricing"), ("support.html", "Support")]
    nav = "".join(
        f'<a href="/{"" if h == "index.html" else h[:-5]}"{" aria-current=\"page\"" if h == current else ""}>{t}</a>'
        for h, t in links)
    html = f'''<!doctype html>
<html lang="en" class="no-js">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{desc}">
<meta name="theme-color" content="#0b0f1a">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:type" content="website">
<meta property="og:image" content="/assets/og.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/assets/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/styles.css">
</head>
<body>
<header class="nav">
  <div class="wrap nav-inner">
    <a class="brand" href="/">{MARK}<span>{APP}</span></a>
    <nav class="nav-links" aria-label="Main">{nav}</nav>
    <div class="nav-cta">
      <a class="btn btn-primary btn-sm" href="{STORE_URL}">Get the app</a>
      <button class="menu-btn" aria-label="Menu" aria-expanded="false">{I["menu"]}</button>
    </div>
  </div>
</header>
<main>
{body}
</main>
<footer class="footer">
  <div class="wrap">
    <div class="footer-grid">
      <div>
        <a class="brand" href="/">{MARK}<span>{APP}</span></a>
        <p>Growth tracking, posture and healthy habits for growing kids, teens and the adults who want to stand tall. Built for iPhone.</p>
      </div>
      <div><h4>Product</h4><ul><li><a href="/features">Features</a></li><li><a href="/pricing">Pricing</a></li><li><a href="{STORE_URL}">Download</a></li></ul></div>
      <div><h4>Help</h4><ul><li><a href="/support">Support</a></li><li><a href="/support#faq">FAQ</a></li><li><a href="mailto:{EMAIL}">{EMAIL}</a></li></ul></div>
      <div><h4>Legal</h4><ul><li><a href="/privacy">Privacy Policy</a></li><li><a href="/terms">Terms of Use</a></li></ul></div>
    </div>
    <div class="footer-base">
      <span>&copy; <span data-year>2026</span> {COMPANY}. All rights reserved.</span>
      <span>{APP} is a wellness app and does not provide medical advice.</span>
    </div>
  </div>
</footer>
<script src="/assets/main.js" defer></script>
</body>
</html>
'''
    with open(os.path.join(OUT, fname), "w") as f:
        f.write(html)


# Stick-figure posture comparison used on home and features
def posture_figs(h=150):
    return f'''<svg viewBox="0 0 60 150" class="bad" style="height:{h}px"><circle cx="38" cy="14" r="9" style="color:#687083"/><path d="M34 26 C 26 50, 30 70, 30 90 M30 90 L22 146 M30 90 L38 146 M32 38 L14 72 M32 38 L48 70"/></svg>
  <svg viewBox="0 0 60 150" class="good" style="height:{h}px"><circle cx="30" cy="12" r="9" style="color:{GOLD}"/><path d="M30 24 L30 90 M30 90 L22 146 M30 90 L38 146 M30 36 L14 72 M30 36 L46 72"/><line x1="4" y1="36" x2="56" y2="36" style="stroke:{GOLD};stroke-width:1;stroke-dasharray:3 3;opacity:.6"/><line x1="4" y1="90" x2="56" y2="90" style="stroke:{GOLD};stroke-width:1;stroke-dasharray:3 3;opacity:.6"/></svg>'''


# ---------- Home ----------
home = f'''
<section class="hero">
  <div class="wrap hero-grid">
    <div>
      <span class="eyebrow reveal">Height &middot; Growth &middot; Posture</span>
      <h1 class="reveal" data-delay="1">Grow into your<br><em>full height.</em></h1>
      <p class="lede reveal" data-delay="2">Real CDC growth charts, an honest adult-height estimate, guided posture routines and a 30-second camera posture check. For teens, parents and adults, and private on your iPhone.</p>
      <div class="hero-actions reveal" data-delay="3">
        {store_btn()}
        <a class="btn btn-ghost" href="/features">See how it works</a>
      </div>
      <div class="hero-meta reveal" data-delay="3">
        <span>{I["star"]} Free {TRIAL} trial</span>
        <span>{I["lock"]} No account needed</span>
        <span>{I["family"]} Profiles for the whole family</span>
      </div>
    </div>
    <div class="phone-stage reveal" data-delay="2">
      <div class="phone">
        <div class="phone-screen">
          <div><div class="ps-greet">Tuesday &middot; Today's plan</div><div class="ps-title">Good morning,<br>Alex</div></div>
          <div class="ring-card">
            <svg class="ring" viewBox="0 0 76 76"><circle class="track" cx="38" cy="38" r="32"/><circle class="prog" cx="38" cy="38" r="32"/></svg>
            <div class="ring-copy"><strong>164.2 cm</strong><span>62nd percentile<br>Growing steadily</span></div>
          </div>
          <div class="ps-row">
            <div class="mini"><small>Posture</small><strong>78 / 100</strong></div>
            <div class="mini"><small>Streak</small><strong>12 days</strong></div>
          </div>
          <div class="mini">
            <small>Plan this week</small>
            <div class="bars" style="margin-top:10px"><i class="on" style="--h:70%"></i><i class="on" style="--h:85%"></i><i class="on" style="--h:60%"></i><i class="on" style="--h:95%"></i><i class="on" style="--h:80%"></i><i style="--h:30%"></i><i style="--h:25%"></i></div>
          </div>
          <div class="ps-session"><small>Today's routine &middot; 6 min</small><strong>Stand-tall posture</strong></div>
        </div>
      </div>
      <div class="float-card fc-1"><strong>Next size in ~6 months</strong><span>Outgrow Forecast</span></div>
      <div class="float-card fc-2"><strong>Shoulders level</strong><span>Posture check &middot; just now</span></div>
    </div>
  </div>
</section>

<section class="strip">
  <div class="wrap strip-inner">
    <div class="stat reveal"><strong>CDC</strong><span>growth charts and percentiles</span></div>
    <div class="stat reveal" data-delay="1"><strong>26 moves</strong><span>across 9 guided routines</span></div>
    <div class="stat reveal" data-delay="2"><strong>30 sec</strong><span>camera posture check</span></div>
    <div class="stat reveal" data-delay="3"><strong>0</strong><span>ads, trackers or data sold</span></div>
  </div>
</section>

<section class="section">
  <div class="wrap">
    <div class="section-head reveal">
      <span class="eyebrow">Why {APP}</span>
      <h2>Growth, measured honestly.</h2>
      <p>Height apps love big promises. {APP} shows you where you really are on the growth chart, gives an estimate with its reasoning, and builds the everyday habits that help you stand at your full height. It's also useful for the practical things growing kids bring, like clothes that suddenly don't fit.</p>
    </div>
    <div class="bento">
      <article class="tile t-span-4 reveal">
        <div class="tag">Posture check</div>
        <h3>See your posture the way others do.</h3>
        <p>Stand in front of your iPhone for 30 seconds, from the front or the side. {APP} scores head, shoulder and hip alignment and picks routines for what it finds. It's analysed on your iPhone, and no photo or video is saved or sent.</p>
        <div class="tile-visual posture-vis">
          {posture_figs()}
          <div class="posture-legend">Head forward &rarr; aligned<br>Shoulders tilted &rarr; level</div>
        </div>
      </article>
      <article class="tile t-span-2 reveal" data-delay="1">
        <div class="icon">{I["ruler"]}</div>
        <div><h3>Real growth charts</h3><p>Height percentiles from the CDC growth charts, explained in plain words, with growth speed read the way clinicians read it.</p></div>
      </article>
      <article class="tile t-span-2 reveal">
        <div class="icon">{I["chart"]}</div>
        <div><h3>An honest estimate</h3><p>Where adult height would land if growth stays on its percentile line. A range with its reasoning, never a guarantee.</p></div>
      </article>
      <article class="tile t-span-2 reveal" data-delay="1">
        <div class="icon">{I["spine"]}</div>
        <div><h3>Guided routines</h3><p>Posture, mobility, core, morning, evening and desk-break routines with a timer, cues and haptics.</p></div>
      </article>
      <article class="tile t-span-2 reveal" data-delay="2">
        <div class="icon">{I["flame"]}</div>
        <div><h3>A daily plan</h3><p>One routine, your habits, food variety and bedtime. Levels, points and a forgiving streak that never shames a missed day.</p></div>
      </article>
      <article class="tile t-span-3 reveal">
        <div class="tag">Gromax Coach</div>
        <h3>Ask anything. It stays on your iPhone.</h3>
        <p>Questions about growth, sleep, food, posture or measuring are answered on your device, using your own data. No invented numbers and no "grow taller" tricks.</p>
        <div class="tile-visual chat">
          <div class="bubble me">Is it normal I grew 4 cm since spring?</div>
          <div class="bubble ai">That's within the usual range for your age and puberty stage. Your growth speed is on the Growth tab, and it's worth bringing to your next check-up.</div>
        </div>
      </article>
      <article class="tile t-span-3 reveal" data-delay="1">
        <span class="new-badge">For parents</span>
        <div class="icon">{I["shoe"]}</div>
        <div><h3>Outgrow Forecast</h3><p>Expected height and clothing size over the next 3, 6 and 12 months, so you can plan before the morning nothing fits.</p></div>
      </article>
      <article class="tile t-span-3 reveal">
        <span class="new-badge">For parents</span>
        <div class="icon">{I["doc"]}</div>
        <div><h3>Doctor visit kit</h3><p>The questions worth asking and a doctor-ready PDF report with the growth chart and measurements.</p></div>
      </article>
      <article class="tile t-span-3 reveal" data-delay="1">
        <div class="icon">{I["moon"]}</div>
        <div><h3>Sleep, food and puberty</h3><p>A bedtime planner that works back from wake-up time, food-variety check-ins across six groups, and a private puberty-stage check.</p></div>
      </article>
    </div>
  </div>
</section>

<section class="section" style="padding-top:0">
  <div class="wrap">
    <div class="section-head reveal">
      <span class="eyebrow">How it works</span>
      <h2>A minute to set up. A few minutes a day.</h2>
    </div>
    <div class="steps">
      <div class="step reveal"><h3>Add a profile</h3><p>Birth date, height and, if you like, both parents' heights. See your percentile and estimate straight away. No account needed.</p></div>
      <div class="step reveal" data-delay="1"><h3>Check your posture</h3><p>A 30-second camera check sets your baseline and picks the routines that help most.</p></div>
      <div class="step reveal" data-delay="2"><h3>Follow today's plan</h3><p>A routine, a few habits, food variety and a bedtime. Measure every few months and watch the chart fill in.</p></div>
    </div>
  </div>
</section>

<section class="section" style="padding-top:0">
  <div class="wrap quote reveal">
    <blockquote>No exercise changes bone length, and {APP} never pretends it does. It helps you understand growth and stand at your full height.</blockquote>
    <cite>The {APP} promise</cite>
  </div>
</section>

<section class="section" style="padding-top:0" id="download">
  <div class="wrap">
    <div class="cta reveal">
      <h2>Stand tall<br>starting today.</h2>
      <p>Your growth result, chart and estimate are always free. Try {APP} Pro free for 3 days with the yearly plan.</p>
      {store_btn()}
    </div>
  </div>
</section>
'''
page("index.html", STORE_NAME, f"{APP}: real CDC growth charts, an honest adult-height estimate, guided posture routines and a 30-second camera posture check. Private on your iPhone.", home, "index.html")


# ---------- Features ----------
def frow(tag, h, p, items, visual, new=False):
    lis = "".join(f"<li>{C}<span>{x}</span></li>" for x in items)
    badge = f' <span class="new-badge inline">{new}</span>' if new else ""
    return f'''<div class="feature-row">
  <div class="fr-copy reveal"><span class="eyebrow">{tag}{badge}</span><h2>{h}</h2><p>{p}</p><ul>{lis}</ul></div>
  <div class="fr-visual reveal" data-delay="1">{visual}</div>
</div>'''


def mini_row(label, text, state=""):
    tick = C.replace("<svg", f'<svg style="width:20px;color:{GOLD}"') if state == "done" else ""
    if state == "now":
        tick = f'<span style="font-size:13px;color:{GOLD}">0:32</span>'
    style = {"now": "border-color:rgba(232,199,122,.45)", "next": "opacity:.6", "later": "opacity:.4"}.get(state, "")
    return f'<div class="mini row" style="{style}"><span><small>{label}</small><strong>{text}</strong></span>{tick}</div>'


routine_vis = '<div class="stack">' + "".join([
    mini_row("Move 1", "Wall angels &middot; 45s", "done"),
    mini_row("Move 2", "Chin tucks &middot; 10 reps", "done"),
    mini_row("Now", "Cat-cow &middot; 45s", "now"),
    mini_row("Move 4", "Thoracic opener &middot; 40s", "next"),
    mini_row("Move 5", "Glute bridge &middot; 12 reps", "later"),
]) + '</div>'

scan_vis = f'<div class="posture-vis" style="justify-content:center">{posture_figs(220)}</div>'

growth_vis = f'''<div style="width:100%;max-width:380px">
  <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:18px"><span class="dim" style="font-size:13px">Height &middot; 62nd percentile</span><strong style="font-family:var(--serif);font-size:44px;font-weight:400">164.2<span class="dim" style="font-size:18px"> cm</span></strong></div>
  <svg viewBox="0 0 300 130" style="width:100%"><defs><linearGradient id="g" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="{GOLD}" stop-opacity=".3"/><stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></linearGradient></defs>
  <path d="M0 118 C 80 96, 180 52, 300 18" fill="none" stroke="#687083" stroke-width="1" stroke-dasharray="4 4"/>
  <path d="M0 126 C 80 108, 180 70, 300 40" fill="none" stroke="#687083" stroke-width="1" stroke-dasharray="4 4"/>
  <path d="M0 122 C 60 106, 130 82, 200 58 L200 130 L0 130Z" fill="url(#g)"/>
  <path d="M0 122 C 60 106, 130 82, 200 58" fill="none" stroke="{GOLD}" stroke-width="2.5"/>
  <path d="M200 58 C 240 46, 270 36, 300 30" fill="none" stroke="{GOLD}" stroke-width="2" stroke-dasharray="2 5" stroke-linecap="round"/>
  <circle cx="200" cy="58" r="4" fill="{GOLD}"/></svg>
  <div style="display:flex;justify-content:space-between;font-size:12px;color:#687083;margin-top:8px"><span>Age 11</span><span>12</span><span>13</span><span>14</span></div>
</div>'''

outgrow_vis = '<div class="stack">' + "".join([
    mini_row("In 3 months", "151 cm &middot; same clothing size"),
    mini_row("In 6 months", "153 cm &middot; likely the next size up", "next"),
    mini_row("In 12 months", "157 cm &middot; one more size after that", "later"),
]) + '</div>'

sleep_vis = '''<div class="stack">
  <div class="mini"><small>Wake 7:00 &middot; Age 13</small><strong style="font-size:26px">Bed by 21:30</strong><p class="dim" style="font-size:13px;margin:6px 0 0">8&ndash;10 hours recommended for your age</p></div>
  <div class="ps-row"><div class="mini"><small>Wind-down</small><strong>21:00</strong></div><div class="mini"><small>Food groups</small><strong>5 / 6</strong></div></div>
</div>'''

doctor_vis = '''<div class="doc-card">
  <div class="doc-head"><strong>Growth report</strong><span>Jan&ndash;Oct 2026</span></div>
  <div class="doc-line w80"></div><div class="doc-line w60"></div>
  <svg viewBox="0 0 200 60" style="width:100%;margin:14px 0"><path d="M0 52 C 50 44, 110 28, 200 10" fill="none" stroke="#e8c77a" stroke-width="2"/></svg>
  <div class="doc-line w90"></div><div class="doc-line w70"></div><div class="doc-line w40"></div>
  <div class="doc-foot">Questions to ask &middot; 4</div>
</div>'''

family_vis = '<div class="stack">' + "".join([
    mini_row("Maya &middot; 13", "62nd percentile &middot; routine done", "done"),
    mini_row("Leo &middot; 10", "New height logged: 141 cm", "done"),
    mini_row("You", "Posture check due Sunday", "next"),
]) + '</div>'

coach_vis = '''<div class="chat" style="width:100%;max-width:360px">
  <div class="bubble me">How should I measure my height at home?</div>
  <div class="bubble ai">Barefoot, heels against a wall, looking straight ahead. Measure at the same time of day each time, since you're slightly taller in the morning.</div>
  <div class="bubble me">Will stretching make me taller?</div>
  <div class="bubble ai">No exercise changes bone length. Routines help posture and mobility, which can help you stand at your full height.</div>
</div>'''

features = f'''
<section class="page-head">
  <div class="wrap">
    <span class="eyebrow reveal">Features</span>
    <h1 class="reveal" data-delay="1">Everything that helps<br>you stand tall.</h1>
    <p class="reveal" data-delay="2">Growth charts, routines and a private coach in one calm, focused app. No ads, no tracking, no false promises.</p>
  </div>
</section>
<section>
  <div class="wrap">
    {frow("Growth charts", "Know where you are, and how fast you're growing.", "Log height in seconds. See your percentile on the CDC 2000 growth charts, explained in plain words, with your measurements drawn over the percentile curves and growth speed read from measurements months apart.", ["Height percentiles from the CDC charts", "Growth speed, the way clinicians read it", "An adult-height estimate with its reasoning", "Family-height range from both parents' heights"], growth_vis)}
    {frow("Posture check", "Your posture, measured in 30 seconds.", "Stand in front of your iPhone, from the front or the side. Apple's Vision framework scores head, shoulder and hip alignment on your device. Each frame is discarded, and only the score is kept.", ["Head, shoulder and hip alignment", "Front and side views", "Routines picked for what the check found", "No photo or video saved or sent"], scan_vis)}
    {frow("Guided routines", "9 routines. 26 moves. A few minutes a day.", "Posture, mobility, core, morning, evening and desk-break routines with a timer, cues and haptics. They're built to help you stand at your full height and feel good, and the app says plainly that no exercise changes bone length.", ["9 guided routines, 26 moves", "Timer, cues and haptics", "A daily plan with levels, points and a forgiving streak", "11 Learn articles on growth, sleep and food"], routine_vis)}
    {frow("Outgrow Forecast", "Plan before the morning nothing fits.", "From your child's own growth, Gromax estimates height and clothing size over the next 3, 6 and 12 months, so you can plan purchases and hand-me-downs ahead of time.", ["Height in 3, 6 and 12 months", "Expected clothing size", "Follows your child's percentile line", "Updates with every measurement"], outgrow_vis, new="For parents")}
    {frow("Sleep, food and puberty", "The habits that matter while you grow.", "The bedtime planner works back from wake-up time and shows the sleep range for your age, with a wind-down reminder. Food-variety check-ins cover six food groups, and a private puberty-stage check explains what it means for growth.", ["Bedtime planner and wind-down reminder", "Age-based sleep ranges", "Food-variety check-ins across six groups", "Private puberty-stage check"], sleep_vis)}
    {frow("Doctor visit kit", "Walk into appointments prepared.", "Get the questions worth asking, and a doctor-ready PDF report with the growth chart, percentiles and measurements. It's made on your iPhone and shared only if you choose to.", ["Doctor-ready PDF report", "Growth chart and percentile history", "Suggested questions for the visit", "Created on your device"], doctor_vis, new="For parents")}
    {frow("Family profiles", "Every child in one place.", "Track several children from one iPhone with the profile switcher. Gromax Pro supports Apple Family Sharing, so up to five family members can use it at no extra cost.", ["A profile for each child", "Switch profiles in one tap", "Family Sharing for up to five people", "Each profile's data stays on the device"], family_vis)}
    {frow("Gromax Coach", "Answers in seconds, made on your iPhone.", f"Ask about growth, sleep, food, posture or measuring. Answers use your own data and are generated on your device with Apple's on-device model. iPhones without Apple Intelligence get answers from {APP}'s built-in guide.", ["Grounded in your own measurements", "No invented numbers, no medical claims", "Nothing is sent to a server", "Conversations aren't saved after you close them"], coach_vis)}
  </div>
</section>
<section class="section">
  <div class="wrap">
    <div class="cta reveal">
      <h2>Try every feature free.</h2>
      <p>Your first 3 days of {APP} Pro are on us with the yearly plan.</p>
      {store_btn()}
    </div>
  </div>
</section>
'''
page("features.html", f"Features | {APP}", "CDC growth charts and percentiles, an honest adult-height estimate, guided routines, a camera posture check, Outgrow Forecast, a doctor visit kit, family profiles and Gromax Coach.", features, "features.html")


# ---------- Pricing ----------
def li(x, on=True):
    return f'<li{"" if on else " class=\"off\""}>{C if on else I["x"]}<span>{x}</span></li>'


pricing = f'''
<section class="page-head" style="text-align:center">
  <div class="wrap">
    <span class="eyebrow reveal">Pricing</span>
    <h1 class="reveal" data-delay="1">Simple plans.<br>Cancel anytime.</h1>
    <p class="reveal" data-delay="2" style="margin-left:auto;margin-right:auto">Your growth result, chart, estimate, history, habits and starter routines are always free. {APP} Pro unlocks everything else, with a free {TRIAL} trial on the yearly plan.</p>
  </div>
</section>
<section style="padding-bottom:96px">
  <div class="wrap">
    <div class="toggle-wrap reveal">
      <div class="billing-toggle" role="group" aria-label="Billing period">
        <span class="pill" aria-hidden="true"></span>
        <button type="button" data-mode="weekly" aria-pressed="false">Weekly</button>
        <button type="button" data-mode="monthly" aria-pressed="false">Monthly</button>
        <button type="button" data-mode="yearly" aria-pressed="true">Yearly</button>
      </div>
    </div>
    <div class="plans">
      <div class="plan reveal">
        <h3>Free</h3>
        <p class="sub">Always free, no account needed.</p>
        <div class="price"><strong>$0</strong></div>
        <p class="price-note">Free forever</p>
        <ul>
          {li("Growth result, chart &amp; percentile")}
          {li("Adult-height estimate")}
          {li("Measurement history &amp; habits")}
          {li("Starter routines")}
          {li("Your first posture check")}
          {li("Outgrow Forecast &amp; doctor reports", False)}
          {li("Family profiles", False)}
        </ul>
        <a class="btn btn-ghost" href="{STORE_URL}">Download free</a>
      </div>
      <div class="plan featured reveal" data-delay="1">
        <span class="badge">Most popular</span>
        <h3>{APP} Pro</h3>
        <p class="sub">All routines, posture checks, forecasts and reports.</p>
        <div class="price"><strong data-weekly="{WEEKLY}" data-monthly="{MONTHLY}" data-yearly="{YEARLY}">{YEARLY}</strong><span data-weekly="/ week" data-monthly="/ month" data-yearly="/ year">/ year</span></div>
        <p class="price-note" data-weekly="Billed weekly" data-monthly="Billed monthly" data-yearly="Just {YEARLY_PER_WEEK} a week, after a {TRIAL} free trial">Just {YEARLY_PER_WEEK} a week, after a {TRIAL} free trial</p>
        <ul>
          {li("All 9 routines and 26 moves")}
          {li("Weekly posture checks")}
          {li("Outgrow Forecast")}
          {li("Doctor-ready PDF reports")}
          {li("Advanced growth analysis")}
          {li("Family profiles &amp; Family Sharing")}
          {li("Full Learn library &amp; unlimited Gromax Coach")}
        </ul>
        <a class="btn btn-primary" href="{STORE_URL}">Start free trial</a>
      </div>
      <div class="plan reveal" data-delay="2">
        <h3>Lifetime</h3>
        <p class="sub">Pay once. Pro, forever.</p>
        <div class="price"><strong>{LIFETIME}</strong><span>once</span></div>
        <p class="price-note">One-time purchase, never renews</p>
        <ul>
          {li("Everything in Pro")}
          {li("No renewals, ever")}
          {li("Family Sharing")}
        </ul>
        <a class="btn btn-ghost" href="{STORE_URL}">Get lifetime</a>
      </div>
    </div>
    <p class="fine reveal">Prices shown in USD and may vary by country; the app always shows the current App Store price. Payment is charged to your Apple Account. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings &rsaquo; Apple Account &rsaquo; Subscriptions. See our <a href="/terms">Terms of Use</a> and <a href="/privacy">Privacy Policy</a>.</p>
  </div>
</section>
<section class="section" style="padding-top:0">
  <div class="wrap">
    <div class="section-head center reveal"><h2>Compare plans</h2></div>
    <div class="table-scroll reveal">
      <table class="compare">
        <thead><tr><th>Feature</th><th>Free</th><th>Pro</th></tr></thead>
        <tbody>
          <tr><td>Growth result, CDC chart &amp; percentile</td><td class="yes">{C}</td><td class="yes">{C}</td></tr>
          <tr><td>Adult-height estimate</td><td class="yes">{C}</td><td class="yes">{C}</td></tr>
          <tr><td>Measurement history &amp; habits</td><td class="yes">{C}</td><td class="yes">{C}</td></tr>
          <tr><td>Bedtime planner &amp; food check-ins</td><td class="yes">{C}</td><td class="yes">{C}</td></tr>
          <tr><td>Guided routines</td><td class="no">Starter</td><td class="yes">All 9</td></tr>
          <tr><td>Posture check</td><td class="no">First check</td><td class="yes">Weekly</td></tr>
          <tr><td>Gromax Coach</td><td class="no">Limited</td><td class="yes">Unlimited</td></tr>
          <tr><td>Learn library</td><td class="no">Some articles</td><td class="yes">All 11</td></tr>
          <tr><td>Outgrow Forecast</td><td class="no">&mdash;</td><td class="yes">{C}</td></tr>
          <tr><td>Doctor-ready PDF report</td><td class="no">&mdash;</td><td class="yes">{C}</td></tr>
          <tr><td>Advanced growth analysis</td><td class="no">&mdash;</td><td class="yes">{C}</td></tr>
          <tr><td>Family profiles</td><td class="no">&mdash;</td><td class="yes">{C}</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</section>
<section class="section" style="padding-top:0">
  <div class="wrap faq">
    <div class="section-head center reveal"><h2>Billing questions</h2></div>
    <details class="reveal"><summary>How does the free trial work?</summary><div>The yearly plan starts with 3 days free. If you don't cancel at least 24 hours before the trial ends, it converts to a paid subscription at the price shown.</div></details>
    <details class="reveal"><summary>How do I cancel?</summary><div>Go to Settings &rsaquo; Apple Account &rsaquo; Subscriptions on your iPhone, or Profile &rsaquo; Manage subscription in the app. You keep Pro until the end of the period you paid for. Deleting the app, its data or your account doesn't cancel a subscription. The lifetime purchase never renews.</div></details>
    <details class="reveal"><summary>Does one purchase cover my family?</summary><div>Yes. Gromax Pro supports Family Sharing, so up to five family members can use it at no extra cost.</div></details>
    <details class="reveal"><summary>Can I get a refund?</summary><div>Purchases are handled by Apple, so refunds are too. Request one at <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>.</div></details>
    <details class="reveal"><summary>How do I restore Gromax Pro?</summary><div>Profile &rsaquo; Restore purchases, signed in with the Apple Account that bought it. Still stuck? <a href="/support">Contact support</a>.</div></details>
  </div>
</section>
'''
page("pricing.html", f"Pricing | {APP}", f"{APP} is free to download. {APP} Pro is {WEEKLY}/week, {MONTHLY}/month or {YEARLY}/year with a {TRIAL} free trial, or {LIFETIME} once for lifetime access.", pricing, "pricing.html")


# ---------- Support ----------
support = f'''
<section class="page-head">
  <div class="wrap">
    <span class="eyebrow reveal">Support</span>
    <h1 class="reveal" data-delay="1">How can we help?</h1>
    <p class="reveal" data-delay="2">We read every message and usually reply within two working days.</p>
  </div>
</section>
<section>
  <div class="wrap support-grid">
    <div class="contact-cards">
      <div class="contact-card reveal"><h3>Email us</h3><p>Questions about the app, your account or a feature idea.</p><a class="link" href="mailto:{EMAIL}">{EMAIL}</a></div>
      <div class="contact-card reveal" data-delay="1"><h3>Billing &amp; refunds</h3><p>Purchases are billed by Apple. Manage or cancel in Settings &rsaquo; Apple Account &rsaquo; Subscriptions, or Profile &rsaquo; Manage subscription in the app. Refunds are requested from Apple.</p><a class="link" href="https://reportaproblem.apple.com">reportaproblem.apple.com</a></div>
      <div class="contact-card reveal" data-delay="2"><h3>Delete your data</h3><p>Delete everything on your iPhone in Profile &rsaquo; Privacy &amp; data &rsaquo; Delete all data. To delete your account and backup: Profile &rsaquo; Account &rsaquo; Delete account.</p><a class="link" href="/privacy">Privacy Policy</a></div>
    </div>
    <div class="form reveal" data-delay="1">
      <form name="support" method="POST" data-netlify="true" netlify-honeypot="company" action="/support?sent=1">
        <h2>Send a message</h2>
        <p>If something went wrong, include your iPhone model, iOS version and what you were doing.</p>
        <input type="hidden" name="form-name" value="support">
        <p class="hidden"><label>Leave this empty <input name="company"></label></p>
        <div class="field-row">
          <div class="field"><label for="name">Name</label><input id="name" name="name" autocomplete="name" required></div>
          <div class="field"><label for="email">Email</label><input id="email" name="email" type="email" autocomplete="email" required></div>
        </div>
        <div class="field"><label for="topic">Topic</label>
          <select id="topic" name="topic"><option>Account &amp; backup</option><option>Subscription &amp; billing</option><option>Bug report</option><option>Feature request</option><option>Privacy &amp; data</option><option>Something else</option></select>
        </div>
        <div class="field"><label for="message">Message</label><textarea id="message" name="message" required></textarea></div>
        <button class="btn btn-primary" type="submit" style="width:100%">Send message</button>
      </form>
      <div class="form-success" role="status"><h2>Thanks, message sent.</h2><p class="dim">We'll reply to your email within two working days.</p></div>
    </div>
  </div>
</section>
<section class="section" id="faq" style="padding-top:0">
  <div class="wrap faq">
    <div class="section-head center reveal"><span class="eyebrow">FAQ</span><h2>Common questions</h2></div>
    <details class="reveal"><summary>Where is my data?</summary><div>On your iPhone. If you sign in (optional), a backup is kept with your account so you can restore it on a new iPhone.</div></details>
    <details class="reveal"><summary>Can routines make me taller?</summary><div>No exercise changes bone length. Routines help posture, mobility and core strength, which can help you stand at your full height.</div></details>
    <details class="reveal"><summary>Is the adult-height estimate a prediction?</summary><div>It shows where height would land if growth stays in its current percentile channel on the CDC chart. It's not a guarantee.</div></details>
    <details class="reveal"><summary>Is the posture check recorded?</summary><div>No. The camera image is analysed on your iPhone and discarded; only the score is kept.</div></details>
    <details class="reveal"><summary>Why are Gromax Coach answers short or from the guide?</summary><div>Conversational answers need Apple Intelligence on a supported iPhone. Other iPhones get answers from {APP}'s built-in guide.</div></details>
    <details class="reveal"><summary>How do I restore Gromax Pro?</summary><div>Profile &rsaquo; Restore purchases, signed in with the Apple Account that bought it.</div></details>
    <details class="reveal"><summary>How do I cancel?</summary><div>Settings &rsaquo; Apple Account &rsaquo; Subscriptions on your iPhone, or Profile &rsaquo; Manage subscription in the app. The lifetime purchase never renews.</div></details>
    <details class="reveal"><summary>How do I delete everything?</summary><div>Profile &rsaquo; Privacy &amp; data &rsaquo; Delete all data. To delete your account and backup: Profile &rsaquo; Account &rsaquo; Delete account.</div></details>
  </div>
</section>
'''
page("support.html", f"Support | {APP}", f"Get help with {APP}: contact support, manage your subscription, delete your data and read common questions.", support, "support.html")


# ---------- Legal ----------
# Privacy and terms text is copied from the app (site/privacy.html and site/terms.html on the
# stature-app branch, which are generated from the in-app text) so the web and in-app versions match.
# If the app's legal text changes, update these sections to the same wording.
def legal(fname, title, heading, intro, sections, desc):
    toc = "".join(f'<li><a href="#{sid}">{h}</a></li>' for sid, h, _ in sections)
    body_secs = "".join(f'<h2 id="{sid}">{h}</h2>{b}' for sid, h, b in sections)
    body = f'''
<section class="page-head">
  <div class="wrap"><span class="eyebrow">Legal</span><h1>{heading}</h1><p>{intro}</p></div>
</section>
<section>
  <div class="wrap prose">
    <p class="updated">Effective {EFFECTIVE}</p>
    <nav class="toc" aria-label="Contents"><strong>Contents</strong><ol>{toc}</ol></nav>
    {body_secs}
  </div>
</section>'''
    page(fname, title, desc, body)


privacy_sections = [
 ("in-short", "In short", f"<p>{APP} keeps your growth data on your device. An account is optional. If you don't create one, we, the developer, don't collect, receive, sell or share personal data. If you do create one to back up your profiles, we keep your email address and that backup only to provide the backup. There are no ads, no analytics and no tracking.</p>"),
 ("on-device", "What the app stores on your device", "<p>Profiles you create: an optional nickname, birth date, the growth chart used (female or male), height measurements, optional parents' heights, habit check-ins, routines you complete, posture-check scores, bedtime settings, food-group check-ins, optional puberty-check answers and your preferences.</p><p>This data is saved on your device with iOS data protection. Unless you sign in to back it up, it is not sent to us or to any server.</p>"),
 ("account", "Optional account and backup", "<p>You can sign in with Apple or with an email and password. If you do, we store your email address (Sign in with Apple lets you hide your real one) and a copy of the data listed above, so you can restore it on another iPhone. It is sent over an encrypted connection and stored by our hosting provider, Supabase, in a database where each account can only read its own backup.</p><p>We use the backup only to back up and restore your data. We never sell it, share it or use it for advertising. You can delete your account and its backup at any time in Profile &rsaquo; Account &rsaquo; Delete account.</p>"),
 ("camera", "Camera and posture check", "<p>The posture check uses the front camera. Each frame is analysed on your device with Apple's Vision framework and then discarded. No photo or video is saved or sent. Only the resulting score and alignment readings are kept with the profile.</p>"),
 ("coach", "Gromax Coach", f"<p>Questions are answered on your device, using Apple's on-device model where available or {APP}'s built-in guide. Your questions and the answers are not sent to us or to anyone else, and conversations are not saved after you close them. The app only keeps a count of questions asked each day.</p>"),
 ("purchases", "Purchases", "<p>Subscriptions and the lifetime purchase are processed by Apple. We don't receive your name, email or payment details from Apple. The app checks your purchase status on your device using Apple's StoreKit. Apple's privacy policy applies to purchases.</p>"),
 ("reports", "Reminders, reports and exports", "<p>Reminders are scheduled on your device. Reports (PDF) and data exports (JSON) are created on your device and are only shared if you choose to share them.</p>"),
 ("children", "Children", f"<p>{APP} is designed for parents and caregivers to track a child's growth, and for teenagers and adults to track their own. Profiles for children under 13 are created and managed by a parent, and a child's data is only backed up if the parent signs in with their own account. We don't knowingly let children under 13 create accounts.</p>"),
 ("deleting", "Backups and deleting your data", "<p>You can delete everything on your device at any time in Profile &rsaquo; Privacy &amp; data &rsaquo; Delete all data. Deleting the app also removes its data from the device. Deleting your account removes its backup from our server. If you use iCloud Backup, Apple may include app data in your device backup according to your iCloud settings.</p>"),
 ("changes", "Changes and contact", f'<p>If this policy changes, the new version will appear in the app and on our website with a new effective date. Questions: <a href="mailto:{PRIVACY_EMAIL}">{PRIVACY_EMAIL}</a>.</p>'),
]
legal("privacy.html", f"Privacy Policy | {APP}", "Privacy Policy", f"How {APP} handles your information.", privacy_sections, f"Privacy Policy for the {STORE_NAME} iPhone app.")

terms_sections = [
 ("medical", "Not medical advice", f"<p>{APP} shows measurements and growth-chart context for information. It does not diagnose, treat or prevent any condition. Estimates are not guarantees. Routines and the posture check support everyday posture and mobility habits; they don't change bone length. Talk to a doctor or other qualified health professional about any health concern, and stop any exercise that causes pain.</p>"),
 ("pro", f"{APP} Pro", f'<p>{APP} Pro is sold by Apple as an auto-renewable subscription (weekly, monthly or yearly) or as a one-time lifetime purchase. The price and billing period are shown before you buy. Payment is charged to your Apple Account. A subscription renews automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel it in Settings &rsaquo; Apple Account &rsaquo; Subscriptions. A free trial, if offered, converts to a paid subscription unless cancelled before it ends. Deleting the app, its data or your account does not cancel a subscription.</p><p>Apple\'s Standard Licensed Application End User License Agreement applies: <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">https://www.apple.com/legal/internet-services/itunes/dev/stdeula/</a></p>'),
 ("accounts", "Accounts", "<p>An account is optional and only used for backup. Keep your password safe. You can delete your account at any time in the app.</p>"),
 ("using", "Using the app", f"<p>Use {APP} for personal, non-commercial purposes. Enter information you have the right to enter, such as your own or your child's measurements.</p><p>The app is provided as is. To the extent permitted by law, we are not liable for decisions made based on information shown in the app.</p>"),
 ("changes", "Changes", "<p>We may update these terms. The current version is always available in the app with its effective date.</p>"),
]
legal("terms.html", f"Terms of Use | {APP}", "Terms of Use", f"The terms that apply when you use {APP}.", terms_sections, f"Terms of Use and subscription terms for the {STORE_NAME} iPhone app.")



# ---------- 404 ----------
page("404.html", f"Page not found | {APP}", "Page not found.", '''
<section class="page-head" style="text-align:center;padding:160px 0">
  <div class="wrap"><span class="eyebrow">404</span><h1>Lost your footing?</h1><p style="margin-left:auto;margin-right:auto">The page you're looking for doesn't exist.</p><div style="margin-top:32px"><a class="btn btn-primary" href="/">Back home</a></div></div>
</section>''')

print("Built pages into", OUT)
