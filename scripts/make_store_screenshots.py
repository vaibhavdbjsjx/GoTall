#!/usr/bin/env python3
"""Composes App Store screenshots (1320 x 2868, 6.9-inch iPhone) from raw simulator captures.

Usage: python3 scripts/make_store_screenshots.py <raw-dir> <out-dir>
Expects store-raw-01.png ... store-raw-06.png from scripts/capture_screenshots.sh (Pro Max simulator).
"""
import sys, pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
SLIDES = [
    ("Growth, beautifully\nunderstood.", "Real CDC percentiles, explained in plain words."),
    ("See the whole\ngrowth story", "Every measurement on the CDC growth chart."),
    ("Ask Linden\nanything", "Private answers, made on your iPhone."),
    ("A doctor-ready\nreport", "Chart, history and methods in one clear PDF."),
    ("Small habits.\nNo guilt.", "Gentle check-ins that forgive a missed day."),
    ("Go deeper\nwith Premium", "Percentile history, growth speed, estimate trends."),
]

def font(size, bold):
    candidates = (["/System/Library/Fonts/SFNSRounded.ttf", "/System/Library/Fonts/SFNS.ttf"] if bold else ["/System/Library/Fonts/SFNS.ttf"]) + \
        ["/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
         "/System/Library/Fonts/Helvetica.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]
    for path in candidates:
        try:
            f = ImageFont.truetype(path, size)
            try:
                f.set_variation_by_name("Bold" if bold else "Regular")
            except Exception:
                pass
            return f
        except Exception:
            continue
    return ImageFont.load_default()

def background():
    img = Image.new("RGB", (W, H))
    px = img.load()
    top, bottom = (8, 80, 68), (20, 128, 106)
    for y in range(H):
        t = y / H
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = c
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((-W * 0.3, -H * 0.15, W * 1.0, H * 0.35), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    return Image.composite(Image.new("RGB", (W, H), (150, 222, 196)), img, glow)

def compose(raw_path, headline, sub, out_path):
    canvas = background()
    d = ImageDraw.Draw(canvas)
    cream = (248, 246, 240)
    y = 150
    for line in headline.split("\n"):
        f = font(108, True)
        w = d.textlength(line, font=f)
        d.text(((W - w) / 2, y), line, font=f, fill=cream)
        y += 124
    f2 = font(48, False)
    w = d.textlength(sub, font=f2)
    d.text(((W - w) / 2, y + 26), sub, font=f2, fill=(205, 236, 224))

    shot = Image.open(raw_path).convert("RGB")
    scale = 1030 / shot.width
    shot = shot.resize((1030, int(shot.height * scale)), Image.LANCZOS)
    top = H - shot.height + 40 if H - shot.height + 40 > y + 140 else y + 140
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width, shot.height + 200), radius=92, fill=255)
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(((W - shot.width) / 2, top + 30, (W + shot.width) / 2, H + 200), radius=92, fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(50))
    canvas = Image.composite(Image.new("RGB", (W, H), (2, 30, 25)), canvas, shadow)
    frame = Image.new("RGB", (shot.width + 28, shot.height + 228), (20, 22, 24))
    fmask = Image.new("L", frame.size, 0)
    ImageDraw.Draw(fmask).rounded_rectangle((0, 0, frame.width, frame.height), radius=106, fill=255)
    canvas.paste(frame, (int((W - frame.width) / 2), top - 14), fmask)
    canvas.paste(shot, (int((W - shot.width) / 2), top), mask)
    canvas.save(out_path, "PNG")

def main():
    raw, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    made = 0
    for i, (headline, sub) in enumerate(SLIDES, start=1):
        src = raw / f"store-raw-{i:02d}.png"
        if src.exists():
            compose(src, headline, sub, out / f"appstore-{i:02d}.png")
            made += 1
    print(f"composed {made} App Store screenshots in {out}")

main()
