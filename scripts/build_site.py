#!/usr/bin/env python3
"""Builds the public pages in site/ (privacy, terms, support, index) for App Store Connect.

The privacy policy and terms are generated from Sources/GrowthCore/Brand/LegalDocuments.swift, so the website
and the in-app text can't drift apart. Run: python3 scripts/build_site.py
"""
import html, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SWIFT = (ROOT / "Sources/GrowthCore/Brand/LegalDocuments.swift").read_text()
NAME, ASSISTANT = "Stature", "Stature Coach"

def subst(text):
    text = text.replace("\\(name)", NAME).replace("\\(BrandConfig.current.assistantName)", ASSISTANT)
    return text.replace('\\"', '"')

def document(var):
    body = SWIFT.split(f"public static var {var}: LegalDocument")[1].split("public static var")[0]
    title = re.search(r'title: "([^"]+)", effectiveDate', body).group(1)
    date = re.search(r'static let effective = "([^"]+)"', SWIFT).group(1)
    sections = []
    for m in re.finditer(r'Section\(title: "((?:[^"\\]|\\.)*)", paragraphs: \[(.*?)\]\)', body, re.S):
        paras = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2))
        sections.append((subst(m.group(1)), [subst(p) for p in paras]))
    return title, date, sections

STYLE = """
:root{--bg:#F7F4EE;--surface:#fff;--text:#14161C;--muted:#5A5F6B;--accent:#8A6418;--soft:#F3E8CF;--line:#E4DDCF}
@media (prefers-color-scheme: dark){:root{--bg:#0B0F1A;--surface:#151B2A;--text:#F4F1EA;--muted:#A3ABBD;--accent:#E8C77A;--soft:#2A2618;--line:#283045}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:17px/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Roboto,sans-serif}
main{max-width:720px;margin:0 auto;padding:40px 16px 64px}a{color:var(--accent)}h1,h2{font-family:"New York",ui-serif,Georgia,serif}
.brand{display:flex;align-items:center;gap:12px;font-weight:700;color:var(--accent);letter-spacing:.08em;text-transform:uppercase;font-size:13px}
.brand img{width:36px;height:36px;border-radius:9px}h1{font-size:34px;line-height:1.15;margin:18px 0 6px}
.date{color:var(--muted);margin:0 0 28px}h2{font-size:19px;margin:28px 0 6px}p{color:var(--muted);margin:0 0 12px}
.card{background:var(--surface);border:1px solid var(--line);border-radius:18px;padding:20px 22px;margin:18px 0}
nav a{margin-right:16px;font-weight:600;text-decoration:none}footer{margin-top:40px;color:var(--muted);font-size:14px}
"""

def page(title, inner):
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · {NAME}</title><style>{STYLE}</style></head>
<body><main>
<div class="brand"><img src="icon.png" alt="">{NAME}</div>
{inner}
<footer><nav><a href="index.html">Home</a><a href="privacy.html">Privacy</a><a href="terms.html">Terms</a><a href="support.html">Support</a></nav></footer>
</main></body></html>
"""

def legal(var, filename):
    title, date, sections = document(var)
    inner = f"<h1>{html.escape(title)}</h1><p class=\"date\">Effective {html.escape(date)}</p>"
    for heading, paras in sections:
        inner += f"<h2>{html.escape(heading)}</h2>" + "".join(f"<p>{html.escape(p)}</p>" for p in paras)
    (ROOT / "site" / filename).write_text(page(title, inner))

legal("privacy", "privacy.html")
legal("terms", "terms.html")
(ROOT / "site/support.html").write_text(page("Support", """
<h1>Help &amp; support</h1><p class="date">We usually reply within two working days.</p>
<div class="card"><h2>Contact</h2><p>Email: <a href="mailto:support@stature.app"><strong>support@stature.app</strong></a></p></div>
<div class="card"><h2>Common questions</h2>
<p><strong>Where is my data?</strong> On your iPhone. If you sign in (optional), a backup is kept with your account so you can restore it on a new iPhone.</p>
<p><strong>How do I restore Stature Pro?</strong> Profile › Restore purchases, signed in with the Apple Account that bought it.</p>
<p><strong>How do I cancel?</strong> Settings › Apple Account › Subscriptions on your iPhone, or Profile › Manage subscription in the app. The lifetime purchase never renews.</p>
<p><strong>Can routines make me taller?</strong> No exercise changes bone length. Routines help posture, mobility and core strength, which can help you stand at your full height.</p>
<p><strong>Is the posture check recorded?</strong> No. The camera image is analysed on your iPhone and discarded; only the score is kept.</p>
<p><strong>Why are Stature Coach answers short or from the guide?</strong> Conversational answers need Apple Intelligence on a supported iPhone. Other iPhones get answers from Stature's built-in guide.</p>
<p><strong>Is the adult-height estimate a prediction?</strong> It shows where height would land if growth stays in its current percentile channel on the CDC chart. It's not a guarantee.</p>
<p><strong>How do I delete everything?</strong> Profile › Privacy &amp; data › Delete all data. To delete your account and backup: Profile › Account › Delete account.</p></div>
"""))
(ROOT / "site/index.html").write_text(page("Growth, measured honestly", """
<h1>Growth, measured honestly.</h1>
<p class="date">Stature tracks height with real CDC growth charts, explains it honestly, and gives you a daily plan for posture, sleep and food.</p>
<div class="card"><h2>What's inside</h2>
<p>Percentiles and a clear growth chart · an honest adult-height estimate with its reasoning · guided posture and mobility routines · a 30-second camera posture check · bedtime planner · Outgrow Forecast for kids · a doctor-ready PDF report · Stature Coach, answered on your iPhone.</p></div>
<div class="card"><h2>Private by design</h2><p>No ads, no tracking. Your data stays on your iPhone unless you choose to back it up.</p></div>
"""))
print("site/ built")
