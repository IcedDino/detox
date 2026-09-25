"""Render preview PNGs from the editable SVGs using the local Edge browser."""

from pathlib import Path
import subprocess
import tempfile
from PIL import Image, ImageDraw


OUT = Path(__file__).resolve().parent
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
EXPORTS = {
    "conceptos": (1600, 1060),
    "app_icon": (512, 512),
    "app_icon_claro": (512, 512),
    "logo_fondo_oscuro": (1520, 428),
    "logo_fondo_claro": (1520, 428),
}

if not EDGE.exists():
    raise SystemExit("Microsoft Edge was not found for preview export.")

with tempfile.TemporaryDirectory(prefix="detox-logo-edge-") as profile:
    for name, (width, height) in EXPORTS.items():
        source = OUT / f"{name}.svg"
        target = OUT / f"{name}.png"
        result = subprocess.run(
            [
                str(EDGE),
                "--headless=new",
                "--disable-gpu",
                "--no-first-run",
                "--hide-scrollbars",
                "--force-device-scale-factor=1",
                f"--user-data-dir={profile}",
                f"--window-size={width},{height}",
                f"--screenshot={target}",
                source.as_uri(),
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0 or not target.exists():
            raise RuntimeError(f"Could not render {source.name}: {result.stderr}")
        print(f"{target.name}: {target.stat().st_size} bytes")

icon = Image.open(OUT / "app_icon.png").convert("RGB")
sample = Image.new("RGB", (600, 190), "#F4F7F3")
draw = ImageDraw.Draw(sample)
x = 24
for size in (128, 64, 48, 32):
    sample.paste(icon.resize((size, size), Image.Resampling.LANCZOS), (x, 16))
    draw.text((x, 154), f"{size} px", fill="#202B26")
    x += size + 20
sample.save(OUT / "prueba_tamanos.png")
print("prueba_tamanos.png: 128, 64, 48 and 32 px")
