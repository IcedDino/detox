"""Export the selected Detox logo to Flutter and Android icon resources."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).resolve().parent / "app_icon.png"
ASSETS = ROOT / "assets" / "images"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

icon = Image.open(SOURCE).convert("RGB")
if icon.size != (512, 512):
    raise ValueError("The source app icon must be 512 x 512 px")

# The full-bleed icon is also used by the logo widget on the sign-in screen.
icon.save(ASSETS / "detox_logo.png", optimize=True)

for density, size in {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}.items():
    target = RES / f"mipmap-{density}" / "ic_launcher.png"
    icon.resize((size, size), Image.Resampling.LANCZOS).save(target, optimize=True)
    print(f"{target.relative_to(ROOT)}: {size} x {size}")

# Recover antialiasing alpha from the flat-color SVG render. This leaves only
# the mint D and dot for Android's adaptive-icon foreground layer.
background = (11, 17, 15)
accent = (139, 199, 174)
pixels = []
for red, green, blue in icon.get_flattened_data():
    alpha = round((green - background[1]) * 255 / (accent[1] - background[1]))
    pixels.append((*accent, max(0, min(255, alpha))))

foreground = Image.new("RGBA", icon.size)
foreground.putdata(pixels)
foreground.save(ASSETS / "detox_adaptive_foreground.png", optimize=True)
foreground.resize((432, 432), Image.Resampling.LANCZOS).save(
    RES / "drawable" / "ic_launcher_foreground.png", optimize=True
)
print("Flutter logo and adaptive foreground exported")
