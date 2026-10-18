#!/usr/bin/env python3
"""Builds the public pages in site/ (privacy, terms, support, index) for App Store Connect.

The privacy policy and terms are generated from Sources/GrowthCore/Brand/LegalDocuments.swift, so the website
and the in-app text can't drift apart. Run: python3 scripts/build_site.py
"""
import html, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SWIFT = (ROOT / "Sources/GrowthCore/Brand/LegalDocuments.swift").read_text()
NAME, ASSISTANT = "Linden", "Ask Linden"

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
:root{--bg:#F6F5F1;--surface:#fff;--text:#15191B;--muted:#565F63;--accent:#09705F;--soft:#DCEFEA;--line:#E2DFD8}
@media (prefers-color-scheme: dark){:root{--bg:#0D1012;--surface:#161A1D;--text:#F1F3F2;--muted:#A7B0B4;--accent:#45C7AC;--soft:#12332D;--line:#2A3034}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:17px/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Roboto,sans-serif}
main{max-width:720px;margin:0 auto;padding:40px 20px 64px}a{color:var(--accent)}
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
<h1>Help &amp; support</h1><p class="date">We usually reply within a few days.</p>
<div class="card"><h2>Contact</h2><p>Email: <strong>SUPPORT_EMAIL</strong> <!-- replace before submission --></p></div>
<div class="card"><h2>Common questions</h2>
<p><strong>Where is my data?</strong> Only on your iPhone. Linden has no accounts and no server.</p>
<p><strong>How do I restore Premium?</strong> Profile › Restore purchases, signed in with the Apple Account that bought it.</p>
<p><strong>How do I cancel?</strong> Settings › Apple Account › Subscriptions on your iPhone, or Profile › Manage subscription in the app.</p>
<p><strong>Why are Ask Linden answers short or from the guide?</strong> Conversational answers need iOS 26 with Apple Intelligence turned on. Other iPhones get answers from Linden's built-in guide.</p>
<p><strong>Is the adult-height estimate a prediction?</strong> No. It shows where height would land if growth stays in its current percentile channel on the CDC chart. It's not a guarantee.</p>
<p><strong>How do I delete everything?</strong> Profile › Privacy &amp; data › Delete all data.</p></div>
"""))
(ROOT / "site/index.html").write_text(page("Growth, beautifully understood", """
<h1>Growth, beautifully understood.</h1>
<p class="date">Linden tracks height with real CDC growth charts, explains it honestly, and keeps everything on your iPhone.</p>
<div class="card"><h2>What's inside</h2>
<p>Percentiles and a clear growth chart · an honest adult-height estimate with its reasoning · growth speed · family-height context · calm daily habits · a doctor-ready PDF report · Ask Linden, answered on your iPhone.</p></div>
<div class="card"><h2>Private by design</h2><p>No accounts, no ads, no tracking. Your data never leaves your device.</p></div>
"""))
print("site/ built")
