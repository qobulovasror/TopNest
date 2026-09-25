from pathlib import Path
from PIL import Image, ImageDraw
import struct

root = Path(__file__).resolve().parents[1]
iconset = root / "Resources" / "TopNest.iconset"
iconset.mkdir(parents=True, exist_ok=True)

image = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((48, 48, 976, 976), radius=235, fill=(16, 23, 34, 255))
draw.rounded_rectangle((58, 58, 966, 966), radius=225, outline=(54, 75, 84, 255), width=11)

mint = (103, 232, 200, 255)
light = (191, 255, 236, 255)
shadow = (34, 66, 68, 255)

# A capsule at the top, with three small tools nested beneath it.
draw.rounded_rectangle((208, 217, 816, 413), radius=98, fill=shadow)
draw.rounded_rectangle((222, 203, 802, 389), radius=93, fill=mint)
draw.rounded_rectangle((254, 236, 770, 356), radius=60, fill=(17, 57, 59, 255))
draw.ellipse((291, 272, 340, 321), fill=light)
draw.rounded_rectangle((380, 273, 704, 319), radius=23, fill=light)

for x, color in [(235, light), (445, mint), (655, light)]:
    draw.rounded_rectangle((x, 501, x + 134, 672), radius=37, fill=shadow)
    draw.rounded_rectangle((x, 491, x + 134, 662), radius=37, fill=color)
    draw.rounded_rectangle((x + 29, 530, x + 105, 546), radius=8, fill=(24, 81, 80, 255))
    draw.rounded_rectangle((x + 29, 566, x + 92, 582), radius=8, fill=(24, 81, 80, 255))

for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        if size == 16 and scale == 2:
            pass
        actual = size * scale
        name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
        image.resize((actual, actual), Image.Resampling.LANCZOS).save(iconset / name)

chunks = []
for kind, filename in [
    (b"ic07", "icon_128x128.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
]:
    data = (iconset / filename).read_bytes()
    chunks.append(kind + struct.pack(">I", len(data) + 8) + data)
payload = b"".join(chunks)
(root / "Resources" / "TopNest.icns").write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
