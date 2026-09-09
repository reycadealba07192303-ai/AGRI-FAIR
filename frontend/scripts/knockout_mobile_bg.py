from PIL import Image
from collections import deque
import os

src = r"c:\Users\reyca\AgriFair\Captone-Project\mobile.png"
out_dir = r"c:\Users\reyca\AgriFair\Captone-Project\frontend\public\app-preview"
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, "mobile-showcase.png")

im = Image.open(src).convert("RGBA")
pixels = im.load()
w, h = im.size


def is_bg(r, g, b, a):
    return a < 10 or (r < 28 and g < 28 and b < 28)


visited = [[False] * w for _ in range(h)]
q = deque()

for x in range(w):
    for y in (0, h - 1):
        r, g, b, a = pixels[x, y]
        if is_bg(r, g, b, a):
            q.append((x, y))
            visited[y][x] = True
for y in range(h):
    for x in (0, w - 1):
        r, g, b, a = pixels[x, y]
        if is_bg(r, g, b, a) and not visited[y][x]:
            q.append((x, y))
            visited[y][x] = True

dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
bg_mask = set()
while q:
    x, y = q.popleft()
    bg_mask.add((x, y))
    for dx, dy in dirs:
        nx, ny = x + dx, y + dy
        if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
            r, g, b, a = pixels[nx, ny]
            if is_bg(r, g, b, a):
                visited[ny][nx] = True
                q.append((nx, ny))

for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        if (x, y) in bg_mask:
            pixels[x, y] = (0, 0, 0, 0)
        elif r < 40 and g < 40 and b < 40:
            near = any((x + dx, y + dy) in bg_mask for dx, dy in dirs)
            if near:
                lum = (r + g + b) / 3
                na = int(min(255, lum * 8))
                pixels[x, y] = (r, g, b, na)

bbox = im.getbbox()
if bbox:
    pad = 24
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(w, r + pad)
    b = min(h, b + pad)
    im = im.crop((l, t, r, b))

im.save(out, "PNG", optimize=True)
print("saved", out, im.size, "bg_pixels", len(bg_mask))
