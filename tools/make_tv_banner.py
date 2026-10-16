# -*- coding: utf-8 -*-
"""Generate the Android TV banner (320x180 px) from the project logo."""
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
LOGO = os.path.join(ROOT, 'assets', 'images', 'logo', 'logo_android.png')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'MiSans-Regular.ttf')
OUT_XHDPI = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res',
                         'drawable-xhdpi', 'banner.png')
OUT_BASE = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res',
                        'drawable', 'banner.png')

SS = 4                     # supersample factor for crisp downscale
W, H = 320 * SS, 180 * SS  # 1280 x 720

img = Image.new('RGB', (W, H), (255, 255, 255))
draw = ImageDraw.Draw(img)

# --- background: subtle diagonal gradient white -> soft green -------------
top = (255, 255, 255)
bottom = (214, 238, 205)   # light green, echoes the character's hair
for y in range(H):
    t = y / float(H - 1)
    # ease-out so the gradient is gentler near the top
    tt = t ** 1.6
    r = int(top[0] + (bottom[0] - top[0]) * tt)
    g = int(top[1] + (bottom[1] - top[1]) * tt)
    b = int(top[2] + (bottom[2] - top[2]) * tt)
    draw.line([(0, y), (W, y)], fill=(r, g, b))

# --- logo -----------------------------------------------------------------
logo = Image.open(LOGO).convert('RGBA')
target_h = int(H * 0.60)   # keep the logo compact so the name still fits
scale = target_h / logo.height
logo = logo.resize((int(logo.width * scale), target_h), Image.LANCZOS)
lx = int(W * 0.06)
ly = H - logo.height - int(H * 0.09)
img.paste(logo, (lx, ly), logo)

# --- app name (auto-fitted into the remaining width) ----------------------
text = 'Kazumi'
tx = lx + logo.width + int(W * 0.05)
right_pad = int(W * 0.055)
avail = W - tx - right_pad

size = int(H * 0.28)
font = ImageFont.truetype(FONT, size)
while size > 40:
    font = ImageFont.truetype(FONT, size)
    bbox = draw.textbbox((0, 0), text, font=font)
    if bbox[2] - bbox[0] <= avail:
        break
    size = int(size * 0.93)

# vertical centering relative to the logo's visual center
bbox = draw.textbbox((0, 0), text, font=font)
th = bbox[3] - bbox[1]
ty = ly + (logo.height - th) // 2 - bbox[1]

# soft shadow for legibility on light backgrounds
shadow = (90, 110, 85)
draw.text((tx + 3 * SS, ty + 3 * SS), text, font=font, fill=shadow)
draw.text((tx, ty), text, font=font, fill=(52, 68, 48))
print('font size:', size, '/ avail px:', avail)

img = img.resize((320, 180), Image.LANCZOS)

os.makedirs(os.path.dirname(OUT_XHDPI), exist_ok=True)
os.makedirs(os.path.dirname(OUT_BASE), exist_ok=True)
img.save(OUT_XHDPI, 'PNG', optimize=True)
img.save(OUT_BASE, 'PNG', optimize=True)
print('written:', OUT_XHDPI, os.path.getsize(OUT_XHDPI), 'bytes')
print('written:', OUT_BASE, os.path.getsize(OUT_BASE), 'bytes')
