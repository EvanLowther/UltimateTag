"""Tag Stadium's pictures, drawn with Pillow: the crests, flags, LED strip, seats, crowd, goal net
and the choreography's two card pictures. images.py writes them as PNGs for upload.py; the map
generator (tools/stadium_layout.py) samples the choreography pictures for its card colours.

Everything is drawn at 4x and scaled down, so the edges are smooth.
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(os.path.dirname(HERE), "icons", "fonts", "Bangers-Regular.ttf")

YEL = (255, 210, 63)
RED = (216, 35, 42)
MAROON = (155, 27, 48)
GOLD = (242, 179, 61)
AWAY = (36, 71, 156)
AWAY_LT = (159, 211, 255)
WHITE = (255, 255, 255)
SKIN = [(241, 194, 125), (224, 172, 105), (198, 134, 66), (141, 85, 36), (255, 219, 172), (245, 208, 169)]
HOME_SHIRTS = [RED, YEL, RED, YEL, (232, 68, 58), (246, 184, 26), MAROON]
AWAY_SHIRTS = [AWAY, WHITE, AWAY, AWAY_LT]

# The wolf's head on the home crest, in a 100 x 100 box, facing left.
WOLF = [(78, 98), (84, 70), (90, 56), (84, 40), (86, 22), (80, 2), (70, 20), (66, 16), (58, 0),
        (52, 22), (44, 30), (36, 34), (16, 42), (6, 44), (2, 50), (6, 54), (18, 56), (30, 58),
        (20, 62), (30, 66), (44, 70), (40, 80), (48, 86), (46, 98)]


def font(size):
    return ImageFont.truetype(FONT, size)


def _shield(cx, cy, s, steps=24):
    """The home crest's heater shield: flat top, straight sides, curving to a point."""
    pts = [(cx - s, cy - 1.1 * s), (cx + s, cy - 1.1 * s), (cx + s, cy + 0.15 * s)]

    def quad(p0, p1, p2):
        for i in range(1, steps + 1):
            t = i / steps
            pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                        (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))

    quad((cx + s, cy + 0.15 * s), (cx + s, cy + 0.85 * s), (cx, cy + 1.3 * s))
    quad((cx, cy + 1.3 * s), (cx - s, cy + 0.85 * s), (cx - s, cy + 0.15 * s))
    return pts


def home_crest(img, cx, cy, s):
    """Draws the home crest (the Taggers) onto an RGBA image: a maroon shield with a gold rim, a
    gold band with TAG and a gold wolf's head."""
    w, h = img.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    shield = _shield(cx, cy, s)
    d.polygon(shield, fill=MAROON + (255,))
    band = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    bd.rectangle([cx - s, cy - 1.1 * s, cx + s, cy - 0.74 * s], fill=GOLD + (255,))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(shield, fill=255)
    band.putalpha(ImageChops.multiply(band.split()[3], mask))
    layer.alpha_composite(band)
    d = ImageDraw.Draw(layer)
    size = max(4, int(0.3 * s))
    d.text((cx, cy - 0.92 * s), "TAG", font=font(size), fill=MAROON + (255,), anchor="mm")
    k, ox, oy = 1.2 * s / 100, cx - 0.6 * s, cy - 0.6 * s
    d.polygon([(ox + x * k, oy + y * k) for x, y in WOLF], fill=GOLD + (255,))
    e = 3.2 * k
    d.ellipse([ox + 38 * k - e, oy + 36 * k - e, ox + 38 * k + e, oy + 36 * k + e], fill=MAROON + (255,))
    d.polygon(shield, outline=GOLD + (255,), width=max(1, int(0.1 * s)))
    img.alpha_composite(layer)


def away_crest(img, cx, cy, s):
    """Draws the away badge (the Runners): navy inside a white ring, a light blue bolt."""
    d = ImageDraw.Draw(img)
    d.ellipse([cx - s, cy - s, cx + s, cy + s], fill=WHITE + (255,))
    d.ellipse([cx - 0.84 * s, cy - 0.84 * s, cx + 0.84 * s, cy + 0.84 * s], fill=AWAY + (255,))
    ring = 0.7 * s
    d.ellipse([cx - ring, cy - ring, cx + ring, cy + ring], outline=WHITE + (255,), width=max(1, int(0.05 * s)))
    k = s / 100
    bolt = [(12, -58), (-30, 8), (-4, 8), (-16, 60), (32, -12), (6, -12)]
    d.polygon([(cx + x * k, cy + y * k) for x, y in bolt], fill=AWAY_LT + (255,))


def _smooth(img, scale):
    return img.resize((img.width // scale, img.height // scale), Image.LANCZOS)


def crest_png(home, size=512):
    img = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
    if home:
        home_crest(img, size * 2, size * 1.68, size * 1.36)
    else:
        away_crest(img, size * 2, size * 2, size * 1.9)
    return _smooth(img, 4)


def flag_png(home, w=512, h=320):
    img = Image.new("RGBA", (w * 4, h * 4), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w * 2, h * 4], fill=(YEL if home else AWAY) + (255,))
    d.rectangle([w * 2, 0, w * 4, h * 4], fill=(RED if home else WHITE) + (255,))
    if home:
        home_crest(img, w * 2, h * 1.86, h * 1.12)
    else:
        away_crest(img, w * 2, h * 2, h * 1.45)
    return _smooth(img, 4)


def led_png(w=1024, h=64):
    """The LED screens' strip. Its arrows point right (+U): the game scrolls it that way."""
    S = 4
    img = Image.new("RGBA", (w * S, h * S), YEL + (255,))
    d = ImageDraw.Draw(img)
    q = w * S // 4
    # 1: yellow with red arrows pointing right.
    for x in range(-32 * S, q, 32 * S):
        d.polygon([(x, 0), (x + 14 * S, 0), (x + 30 * S, 32 * S), (x + 14 * S, h * S), (x, h * S),
                   (x + 16 * S, 32 * S)], fill=RED + (255,))
    # 2: red with ULTIMATE TAG.
    d.rectangle([q, 0, 2 * q, h * S], fill=RED + (255,))
    d.text((1.5 * q, h * S / 2), "ULTIMATE TAG", font=font(40 * S), fill=YEL + (255,), anchor="mm")
    # 3: yellow | red halves with the crest.
    d.rectangle([2 * q, 0, 2.5 * q, h * S], fill=YEL + (255,))
    d.rectangle([2.5 * q, 0, 3 * q, h * S], fill=RED + (255,))
    home_crest(img, 2.5 * q, 28 * S, 19 * S)
    d = ImageDraw.Draw(img)
    # 4: yellow with FORZA TAG! and an arrow either side.
    d.rectangle([3 * q, 0, 4 * q, h * S], fill=YEL + (255,))
    d.text((3.5 * q, h * S / 2), "FORZA TAG!", font=font(40 * S), fill=RED + (255,), anchor="mm")
    for x in (3 * q + 12 * S, 4 * q - 36 * S):
        d.polygon([(x, 18 * S), (x + 22 * S, 32 * S), (x, 46 * S)], fill=RED + (255,))
    out = _smooth(img, S)
    grid = ImageDraw.Draw(out)
    for x in range(0, w, 4):
        grid.line([(x, 0), (x, h)], fill=(0, 0, 0, 36))
    for y in range(0, h, 4):
        grid.line([(0, y), (w, y)], fill=(0, 0, 0, 36))
    return out


def seats_png(away=False, w=104, h=136):
    """One seat on a terrace (2.6 along the row by 3.4 deep): the same looked at either way."""
    img = Image.new("RGBA", (w * 4, h * 4), (150, 156, 165, 255))
    d = ImageDraw.Draw(img)
    seat = (110, 134, 196) if away else (34, 57, 122)
    rim = (150, 170, 220) if away else (52, 80, 150)
    d.rounded_rectangle([12 * 4, 30 * 4, (w - 12) * 4, (h - 30) * 4], radius=40, fill=rim + (255,))
    d.rounded_rectangle([18 * 4, 38 * 4, (w - 18) * 4, (h - 38) * 4], radius=30, fill=seat + (255,))
    return _smooth(img, 4)


def crowd_png(away=False, w=2080, h=400, people=10, seed=1):
    """Ten fans standing in a row (26 studs by 5 at 80 px a stud): feet on the bottom edge, a clear
    band over their heads so the game can bob them up without wrapping."""
    rng = random.Random(seed + (7 if away else 0))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    shirts = AWAY_SHIRTS if away else HOME_SHIRTS
    step = w / people
    for i in range(people):
        cx = step * (i + 0.5) + rng.uniform(-14, 14)
        shirt = rng.choice(shirts)
        skin = rng.choice(SKIN)
        scale = rng.uniform(0.92, 1.05)
        legs_top = h - 120 * scale
        body_top = legs_top - 136 * scale
        head = 92 * scale
        d.rectangle([cx - 46 * scale, legs_top, cx + 46 * scale, h], fill=(40, 43, 51, 255))
        d.rectangle([cx - 64 * scale, body_top, cx + 64 * scale, legs_top], fill=shirt + (255,))
        if rng.random() < 0.7:  # arms up, cheering
            for side in (-1, 1):
                x = cx + side * 82 * scale
                d.rectangle([x - 17 * scale, body_top - 110 * scale, x + 17 * scale, body_top + 40 * scale],
                            fill=shirt + (255,))
                d.rectangle([x - 15 * scale, body_top - 130 * scale, x + 15 * scale, body_top - 108 * scale],
                            fill=skin + (255,))
        d.rectangle([cx - head / 2, body_top - head, cx + head / 2, body_top], fill=skin + (255,))
        if rng.random() < 0.15:  # a scarf in the team's colours
            d.rectangle([cx - 64 * scale, body_top, cx + 64 * scale, body_top + 22 * scale],
                        fill=(rng.choice([YEL, RED]) if not away else WHITE) + (255,))
    return img


def net_png(size=64):
    """A goal net cell: a white cord round the edge, see-through inside (tinted in the game)."""
    img = Image.new("RGBA", (size, size), (255, 255, 255, 46))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, size - 1, size - 1], outline=(255, 255, 255, 255), width=5)
    return img


def choreo_pictures(cols, rows):
    """The two card pictures, `cols` columns across the curve by `rows` rows (row 0 at the top):
    A, the crest with FORZA either side of it and TAG; B, wide yellow and red stripes. Returns two
    lists of rows of (r, g, b). The cards are wider than tall on the stands' slope, so the picture
    is drawn squashed sideways and stretched back by the cards."""
    S = 8
    a = Image.new("RGBA", (cols * S, rows * S), RED + (255,))
    d = ImageDraw.Draw(a)
    d.rectangle([0, 0, cols * S, 1.4 * S], fill=YEL + (255,))
    d.rectangle([0, (rows - 1.4) * S, cols * S, rows * S], fill=YEL + (255,))
    wide = Image.new("RGBA", (int(cols * S / 2.6), rows * S), (0, 0, 0, 0))
    home_crest(wide, wide.width / 2, rows * S * 0.44, rows * S * 0.36)
    wd = ImageDraw.Draw(wide)
    wd.text((wide.width * 0.17, rows * S / 2), "FORZA", font=font(int(rows * S * 0.42)), fill=YEL + (255,), anchor="mm")
    wd.text((wide.width * 0.83, rows * S / 2), "TAG", font=font(int(rows * S * 0.42)), fill=YEL + (255,), anchor="mm")
    wide = wide.resize((cols * S, rows * S), Image.LANCZOS)
    a.alpha_composite(wide)
    b = Image.new("RGBA", (cols * S, rows * S), YEL + (255,))
    bd = ImageDraw.Draw(b)
    stripe = max(1, cols // 8)
    for c in range(0, cols, stripe * 2):
        bd.rectangle([(c + stripe) * S, 0, (c + 2 * stripe) * S, rows * S], fill=RED + (255,))

    def sample(img):
        small = img.convert("RGB").resize((cols, rows), Image.BOX)
        return [[small.getpixel((x, y)) for x in range(cols)] for y in range(rows)]

    return sample(a), sample(b)


def all_images():
    """Every image to upload: name -> PIL image."""
    return {
        "stadium_led": led_png(),
        "stadium_crest_home": crest_png(True),
        "stadium_crest_away": crest_png(False),
        "stadium_flag_home": flag_png(True),
        "stadium_flag_away": flag_png(False),
        "stadium_seats": seats_png(False),
        "stadium_seats_away": seats_png(True),
        "stadium_crowd_home": crowd_png(False),
        "stadium_crowd_away": crowd_png(True),
        "stadium_net": net_png(),
    }
