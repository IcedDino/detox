"""Copy the Detox icon system into the Flutter and Android resources.

Run from the repository root, after generate.py and export_previews.py:
    python docs/brand/detox-icon/aplicar_al_proyecto.py

This is the only script in this folder that writes outside it. Everything it
writes is generated from the PNGs next to it, so running it twice is safe.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
ASSETS = ROOT / "assets" / "images"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

DARK = "#0B110F"

# Legacy launcher bitmaps, matched to the density buckets Android expects.
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# Adaptive icons are authored at 108 dp with a 72 dp safe zone. At xxxhdpi that
# is 432 px, which is the size Android recommends for the foreground layer.
FOREGROUND_SIZE = 432

# Splash symbol, expressed as 88 dp so it reads at the same physical size on
# every screen. Density buckets scale the pixels, not the perceived size.
SPLASH_DP = 88
SPLASH_DENSITIES = {
    "mdpi": 88,
    "hdpi": 132,
    "xhdpi": 176,
    "xxhdpi": 264,
    "xxxhdpi": 352,
}


def load(name: str) -> Image.Image:
    path = OUT / name
    if not path.exists():
        raise SystemExit(f"Missing {name}. Run generate.py and export_previews.py first.")
    return Image.open(path).convert("RGBA")


def write(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}")


def circular(image: Image.Image, size: int) -> Image.Image:
    """Round legacy icon for launchers that ask for ic_launcher_round."""
    square = image.convert("RGBA").resize((size * 4, size * 4), Image.Resampling.LANCZOS)
    mask = Image.new("L", square.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, square.size[0] - 1, square.size[1] - 1), fill=255)
    square.putalpha(mask)
    return square.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    icon = load("icono_app.png")
    if icon.size != (512, 512):
        raise SystemExit(f"icono_app.png must be 512 x 512, found {icon.size}")

    print("Flutter assets")
    write(icon, ASSETS / "detox_logo.png")
    write(load("isotipo_sobre_oscuro.png"), ASSETS / "detox_symbolo_oscuro.png")
    write(load("isotipo_sobre_claro.png"), ASSETS / "detox_symbolo_claro.png")

    print("Legacy launcher icons")
    for density, size in DENSITIES.items():
        target = RES / f"mipmap-{density}"
        write(
            icon.resize((size, size), Image.Resampling.LANCZOS),
            target / "ic_launcher.png",
        )
        write(circular(icon, size), target / "ic_launcher_round.png")

    print("Adaptive icon layers")
    write(
        load("icono_adaptable_frente.png").resize(
            (FOREGROUND_SIZE, FOREGROUND_SIZE), Image.Resampling.LANCZOS
        ),
        RES / "drawable" / "ic_launcher_foreground.png",
    )
    write(
        load("icono_adaptable_monocromo.png").resize(
            (FOREGROUND_SIZE, FOREGROUND_SIZE), Image.Resampling.LANCZOS
        ),
        RES / "drawable" / "ic_launcher_monochrome.png",
    )

    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
        "</adaptive-icon>\n"
    )
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (anydpi / name).write_text(adaptive, encoding="utf-8")
        print(f"  {(anydpi / name).relative_to(ROOT)}")

    print("Splash symbol")
    for density, size in SPLASH_DENSITIES.items():
        write(
            load("isotipo_sobre_claro.png").resize((size, size), Image.Resampling.LANCZOS),
            RES / f"drawable-{density}" / "splash_symbol.png",
        )
        write(
            load("isotipo_sobre_oscuro.png").resize((size, size), Image.Resampling.LANCZOS),
            RES / f"drawable-night-{density}" / "splash_symbol.png",
        )

    print("Done. The manifest, colours and launch background are edited by hand.")
    print(f"Adaptive background colour is {DARK} (see values/colors.xml).")


if __name__ == "__main__":
    main()
