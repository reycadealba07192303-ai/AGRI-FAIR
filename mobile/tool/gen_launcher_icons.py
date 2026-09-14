"""Generate Android launcher icons from AgriFair brand logo."""
from PIL import Image
from pathlib import Path

SRC = Path(r"c:\Users\reyca\AgriFair\Captone-Project\mobile\assets\brand\agrifair_logo.png")
RES = Path(r"c:\Users\reyca\AgriFair\Captone-Project\mobile\android\app\src\main\res")
SPLASH = Path(r"c:\Users\reyca\AgriFair\Captone-Project\mobile\android\app\src\main\res\drawable\splash_logo.png")

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def knock_black(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r < 18 and g < 18 and b < 18:
                px[x, y] = (0, 0, 0, 0)
    bbox = im.getbbox()
    if bbox:
        pad = 24
        l, t, r, b = bbox
        l = max(0, l - pad)
        t = max(0, t - pad)
        r = min(w, r + pad)
        b = min(h, b + pad)
        im = im.crop((l, t, r, b))
    return im


def fit_square(im: Image.Image, size: int, bg=(0xDF, 0xE7, 0xDB, 255)) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), bg)
    # keep some margin so logo isn't edge-clipped
    max_side = int(size * 0.86)
    copy = im.copy()
    copy.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    x = (size - copy.width) // 2
    y = (size - copy.height) // 2
    canvas.paste(copy, (x, y), copy)
    return canvas


def main() -> None:
    logo = knock_black(Image.open(SRC))
    for folder, size in SIZES.items():
        out = RES / folder / "ic_launcher.png"
        fit_square(logo, size).convert("RGBA").save(out, "PNG")
        print("wrote", out, size)

    # splash mark (larger, transparent-friendly on white launch bg)
    splash = fit_square(logo, 288, bg=(255, 255, 255, 0))
    splash.save(SPLASH, "PNG")
    print("wrote", SPLASH)


if __name__ == "__main__":
    main()
