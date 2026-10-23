#!/usr/bin/env python3
"""Composes the App Store product-page Header (5244 x 2950) and Search Results (3840 x 2560) art
from the raw simulator captures, in the same midnight-and-gold look as the screenshots.

Usage: python3 scripts/make_store_banners.py <raw-dir> <icon-png> <out-dir>
"""
import pathlib
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CREAM, GOLD, SOFT = (244, 241, 234), (232, 199, 122), (170, 176, 190)
FONTS = {
    "title": ["/System/Library/Fonts/NewYork.ttf", "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"],
    "sans": ["/System/Library/Fonts/SFNS.ttf", "/usr/share/fonts/opentype/inter/InterDisplay-SemiBold.otf"],
    "body": ["/System/Library/Fonts/SFNS.ttf", "/usr/share/fonts/opentype/inter/InterDisplay-Medium.otf"],
}

def font(kind, size):
    for path in FONTS[kind]:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()

def background(w, h):
    # Vertical midnight gradient with a warm gold glow behind the phones.
    grad = Image.linear_gradient("L").resize((w, h))
    img = Image.composite(Image.new("RGB", (w, h), (21, 27, 42)), Image.new("RGB", (w, h), (9, 12, 22)), grad)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse((w * 0.48, -h * 0.25, w * 1.15, h * 0.95), fill=95)
    glow = glow.filter(ImageFilter.GaussianBlur(w // 18))
    return Image.composite(Image.new("RGB", (w, h), (126, 100, 50)), img, glow)

def phone(raw, width):
    shot = Image.open(raw).convert("RGB")
    shot = shot.resize((width, int(shot.height * width / shot.width)), Image.LANCZOS)
    bezel = int(width * 0.028)
    radius = int(width * 0.135)
    frame = Image.new("RGBA", (shot.width + 2 * bezel, shot.height + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.width - 1, frame.height - 1), radius=radius + bezel, fill=(24, 26, 30, 255),
                                            outline=(70, 66, 58, 255), width=max(2, bezel // 5))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), radius=radius, fill=255)
    frame.paste(shot, (bezel, bezel), mask)
    return frame

def place(canvas, ph, x, y, angle=0):
    if angle:
        ph = ph.rotate(angle, resample=Image.BICUBIC, expand=True)
    shadow = Image.new("L", canvas.size, 0)
    alpha = ph.split()[3]
    shadow.paste(alpha.point(lambda a: int(a * 0.75)), (x + ph.width // 40, y + ph.height // 30))
    shadow = shadow.filter(ImageFilter.GaussianBlur(ph.width // 14))
    canvas.paste(Image.new("RGB", canvas.size, (2, 3, 8)), (0, 0), shadow)
    canvas.paste(ph, (x, y), ph)

def compose(w, h, raw, icon, out, title_lines, sub):
    canvas = background(w, h)
    d = ImageDraw.Draw(canvas)
    s = h / 2950
    left = int(w * 0.075)

    # Phones: three real screens, the middle one forward.
    pw = int(min(1080 * s, 0.205 * w))
    centre_x = int(w - 1.62 * pw)
    top = int(h * 0.12)
    back = [(raw / "store-raw-02.png", -1, 8), (raw / "store-raw-04.png", 1, -8)]
    for path, side, angle in back:
        ph = phone(path, int(pw * 0.86))
        x = centre_x - ph.width // 2 + side * int(pw * 0.70)
        place(canvas, ph, x - (60 if side < 0 else -60), top + int(180 * s), angle)
    front = phone(raw / "store-raw-01.png", pw)
    place(canvas, front, centre_x - front.width // 2, top)

    # Brand block.
    ic = Image.open(icon).convert("RGBA").resize((int(300 * s), int(300 * s)), Image.LANCZOS)
    m = Image.new("L", ic.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, ic.width - 1, ic.height - 1), radius=int(ic.width * 0.225), fill=255)
    y = int(h * 0.20)
    canvas.paste(ic, (left, y), m)
    d.text((left + ic.width + int(60 * s), y + ic.height // 2), "Gromax", font=font("sans", int(150 * s)), fill=CREAM, anchor="lm")
    y += ic.height + int(170 * s)
    # Fit the headline into the space left of the back phone.
    room = centre_x - int(pw * 1.15) - left
    size = int(250 * s)
    while size > 60 and max(d.textlength(t, font=font("title", size)) for t in title_lines) > room:
        size -= 6
    tf = font("title", size)
    for line in title_lines:
        d.text((left, y), line, font=tf, fill=CREAM)
        y += int(size * 1.16)
    y += int(60 * s)
    bsize = int(84 * s)
    while bsize > 30 and d.textlength(sub, font=font("body", bsize)) > room:
        bsize -= 4
    d.text((left, y), sub, font=font("body", bsize), fill=GOLD)
    y += int(190 * s)
    chips = ["CDC growth charts", "Posture check", "Daily plan"]
    cf = font("body", int(min(66 * s, bsize * 0.8)))
    x = left
    for c in chips:
        tw = d.textlength(c, font=cf)
        pad = int(44 * s)
        d.rounded_rectangle((x, y, x + tw + 2 * pad, y + int(120 * s)), radius=int(60 * s), outline=(120, 104, 70), width=max(2, int(4 * s)), fill=(28, 30, 38))
        d.text((x + pad, y + int(60 * s)), c, font=cf, fill=SOFT, anchor="lm")
        x += tw + 2 * pad + int(34 * s)
    canvas.save(out, "PNG", optimize=True)

def main():
    raw, icon, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    compose(3840, 1646, raw, icon, out / "appstore-header-21x9.png", ["Growth,", "measured honestly."], "Charts, routines and a posture check. Private on your iPhone.")
    compose(5244, 2950, raw, icon, out / "appstore-header.png", ["Growth,", "measured honestly."], "Charts, routines and a posture check. Private on your iPhone.")
    compose(3840, 2560, raw, icon, out / "appstore-search.png", ["Growth,", "measured honestly."], "Growth charts, routines, posture check.")
    print(f"composed header and search art in {out}")

if __name__ == "__main__":
    main()
