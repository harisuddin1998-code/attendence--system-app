from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
RED_LIGHT = (200, 16, 46)   # #c8102e
RED_DARK = (151, 8, 31)     # #97081f
FONT_PATH = "C:/Windows/Fonts/arialbd.ttf"


def diagonal_gradient(size, c1, c2):
    base = Image.new("RGB", (size, size), c1)
    top = Image.new("RGB", (size, size), c2)
    mask = Image.new("L", (size, size))
    mdata = []
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            mdata.append(int(255 * t))
    mask.putdata(mdata)
    base.paste(top, (0, 0), mask)
    return base


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def fit_text_font(draw, text, max_width, max_height, start_size):
    size = start_size
    while size > 10:
        font = ImageFont.truetype(FONT_PATH, size)
        bbox = draw.textbbox((0, 0), text, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        if w <= max_width and h <= max_height:
            return font, bbox
        size -= 4
    return ImageFont.truetype(FONT_PATH, size), draw.textbbox((0, 0), text, font=ImageFont.truetype(FONT_PATH, size))


# ---------- 1. Full legacy icon (rounded square, red gradient, white text) ----------
bg = diagonal_gradient(SIZE, RED_LIGHT, RED_DARK)
mask = rounded_mask(SIZE, int(SIZE * 0.22))
full = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
full.paste(bg, (0, 0), mask)

draw = ImageDraw.Draw(full)
text = "MONITOR"
font, bbox = fit_text_font(draw, text, SIZE * 0.8, SIZE * 0.22, 170)
w = bbox[2] - bbox[0]
h = bbox[3] - bbox[1]
pos = ((SIZE - w) / 2 - bbox[0], (SIZE - h) / 2 - bbox[1])
draw.text(pos, text, font=font, fill=(255, 255, 255, 255))
full.save("C:/attendence application/design/icon_full.png")

# ---------- 2. Adaptive icon background (plain gradient, no rounding, no text) ----------
bg.save("C:/attendence application/design/icon_adaptive_bg.png")

# ---------- 3. Adaptive icon foreground (white text on transparent, in safe zone ~66%) ----------
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fdraw = ImageDraw.Draw(fg)
safe = SIZE * 0.66
font2, bbox2 = fit_text_font(fdraw, text, safe * 0.92, safe * 0.34, 130)
w2 = bbox2[2] - bbox2[0]
h2 = bbox2[3] - bbox2[1]
pos2 = ((SIZE - w2) / 2 - bbox2[0], (SIZE - h2) / 2 - bbox2[1])
fdraw.text(pos2, text, font=font2, fill=(255, 255, 255, 255))
fg.save("C:/attendence application/design/icon_adaptive_fg.png")

print("done")
