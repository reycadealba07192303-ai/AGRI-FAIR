from PIL import Image
from pathlib import Path

src = Path(r"c:\Users\reyca\AgriFair\Captone-Project\mobile\assets\brand\agrifair_logo.png")
out_dir = Path(r"c:\Users\reyca\AgriFair\Captone-Project\frontend\public")
out_dir.mkdir(exist_ok=True)

im = Image.open(src).convert("RGBA")
px = im.load()
w, h = im.size
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if r < 18 and g < 18 and b < 18:
            px[x, y] = (0, 0, 0, 0)

bbox = im.getbbox()
if bbox:
    pad = 20
    l, t, r, b = bbox
    im = im.crop((max(0, l - pad), max(0, t - pad), min(w, r + pad), min(h, b + pad)))

for size, name in [(32, "favicon-32.png"), (48, "favicon-48.png"), (180, "apple-touch-icon.png")]:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    copy = im.copy()
    copy.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas.paste(copy, ((size - copy.width) // 2, (size - copy.height) // 2), copy)
    canvas.save(out_dir / name, "PNG")
    print("wrote", name)

Image.open(out_dir / "favicon-32.png").save(out_dir / "favicon.png")
print("done")
