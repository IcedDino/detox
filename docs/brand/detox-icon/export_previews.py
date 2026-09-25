"""Render the SVG system to PNG previews and build the verification sheets.

Run from the repository root with:
    python docs/brand/detox-icon/export_previews.py

SVG rasterisation uses the local Edge browser in headless mode, the same
technique already used by docs/brand/detox-logo. Each SVG is inlined into a
zero-margin HTML page first: opening an .svg file directly makes Chromium use
its image viewer, which rescales the artwork to fit and silently produces a
PNG that does not match the grid. PIL only composes the sheets and measures
contrast, so no extra dependency is required.
"""

from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont


OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
OLD_ICON = ROOT / "assets" / "images" / "detox_logo.png"
FONT_CANDIDATES = (
    Path(r"C:\Windows\Fonts\segoeui.ttf"),
    Path(r"C:\Windows\Fonts\arial.ttf"),
)

EDGE_CANDIDATES = (
    Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
    Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
)

EXPORTS = {
    "icono_app": (512, 512),
    "icono_app_claro": (512, 512),
    "icono_app_alterno": (512, 512),
    "isotipo_blanco": (256, 256),
    "isotipo_negro": (256, 256),
    "isotipo_sobre_oscuro": (512, 512),
    "isotipo_sobre_claro": (512, 512),
    "icono_adaptable_frente": (512, 512),
    "icono_adaptable_monocromo": (512, 512),
    "logo_horizontal_oscuro": (1096, 440),
    "logo_horizontal_oscuro_fondo": (1096, 440),
    "logo_horizontal_claro": (1096, 440),
    "tablero_direcciones": (1400, 900),
    "malla_construccion": (1024, 1024),
    "alternativa_b_ruido_a_calma": (512, 512),
    "alternativa_c_umbral_circular": (512, 512),
}

DARK = (11, 17, 15)
LIGHT = (244, 247, 243)
LIGHT_INK = (32, 43, 38)
LIGHT_MUTED = (104, 116, 108)
SAGE = (139, 199, 174)
SAGE_SOFT = (183, 221, 202)
DEEP = (66, 106, 89)
INK = (232, 237, 234)


def load_font(size: int):
    for candidate in FONT_CANDIDATES:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def find_edge() -> Path:
    for candidate in EDGE_CANDIDATES:
        if candidate.exists():
            return candidate
    raise SystemExit("Microsoft Edge was not found for preview export.")


PAGE = """<!doctype html>
<html><head><meta charset="utf-8">
<style>
html, body {{ margin: 0; padding: 0; width: {w}px; height: {h}px; overflow: hidden; background: transparent; }}
svg {{ display: block; }}
</style></head><body>
{svg}
</body></html>
"""


def render_svgs() -> None:
    edge = find_edge()
    with tempfile.TemporaryDirectory(prefix="detox-icon-edge-") as profile:
        for name, (width, height) in EXPORTS.items():
            source = OUT / f"{name}.svg"
            target = OUT / f"{name}.png"
            page = Path(profile) / f"{name}.html"
            page.write_text(
                PAGE.format(w=width, h=height, svg=source.read_text(encoding="utf-8")),
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    str(edge),
                    "--headless=new",
                    "--disable-gpu",
                    "--no-first-run",
                    "--hide-scrollbars",
                    "--force-device-scale-factor=1",
                    "--default-background-color=00000000",
                    f"--user-data-dir={profile}",
                    f"--window-size={width},{height}",
                    f"--screenshot={target}",
                    page.as_uri(),
                ],
                capture_output=True,
                text=True,
                timeout=60,
            )
            if result.returncode != 0 or not target.exists():
                raise RuntimeError(f"Could not render {source.name}: {result.stderr}")
            rendered = Image.open(target)
            if rendered.size != (width, height):
                raise RuntimeError(
                    f"{target.name} rendered at {rendered.size}, expected {(width, height)}"
                )
            print(f"{target.name}: {rendered.size[0]} x {rendered.size[1]}")


# The design contract, restated here on purpose: a check that imported these
# from generate.py could not catch generate.py being wrong. Keep in sync with
# the constants at the top of generate.py.
GRID = 256.0
OUT_HALF = 88.0
IN_HALF = 44.0
IN_R = 22.0
CORE_R = 22.0
DOOR_Y0 = 106.0
DOOR_Y1 = 150.0
DOOR_HALF = 22.0


def assert_door_is_derived() -> None:
    """The door must span exactly the straight part of the inner wall.

    The inner rounded rect is straight only between its corner arcs, from
    128 - (IN_HALF - IN_R) to 128 + (IN_HALF - IN_R). If the door were taller,
    its straight edge would cut across a corner arc and leave a hairline sliver
    of ink hanging inside the opening — the burr this check exists to prevent.
    """
    flat_half = IN_HALF - IN_R
    if abs(DOOR_HALF - flat_half) > 0.001:
        raise RuntimeError(
            f"the door is {DOOR_HALF * 2:.0f} tall but the inner wall is only straight "
            f"for {flat_half * 2:.0f}; the difference leaves a burr inside the opening"
        )
    if abs((DOOR_Y0 + DOOR_Y1) / 2 - 128) > 0.001:
        raise RuntimeError("the door is not vertically centred on the room")
    if abs((DOOR_Y1 - DOOR_Y0) / 2 - DOOR_HALF) > 0.001:
        raise RuntimeError("the door height and its declared half height disagree")
    print(
        f"door derived correctly: {flat_half * 2:.0f} tall, flush with the inner wall, "
        "no sliver possible"
    )


def ink_runs(image: Image.Image, axis: str, index: int, background: tuple[int, int, int]):
    """Runs of artwork along one line, returned in grid units."""
    scale = image.size[0] / GRID
    limit = image.size[0] if axis == "x" else image.size[1]
    values = []
    for step in range(limit):
        pixel = image.getpixel((step, index) if axis == "x" else (index, step))
        values.append(max(abs(c - d) for c, d in zip(pixel, background)) > 24)
    runs: list[tuple[float, float]] = []
    start = None
    for i, filled in enumerate(values):
        if filled and start is None:
            start = i
        elif not filled and start is not None:
            runs.append((start / scale, (i - 1) / scale))
            start = None
    if start is not None:
        runs.append((start / scale, (limit - 1) / scale))
    return runs


def assert_mark_geometry(
    name: str, scale_factor: float, background: tuple[int, int, int] = DARK
) -> None:
    """Verify the artwork sits exactly where the construction says it should.

    Catches a renderer that rescales the page, a wrong inset and a shifted
    symbol, none of which a size check or an edge check can see.
    """
    image = Image.open(OUT / name).convert("RGB")
    centre = int(image.size[0] / 2)

    def project(value: float) -> float:
        return 128 + (value - 128) * scale_factor

    expected_column = [
        (project(128 - OUT_HALF), project(128 - IN_HALF)),
        (project(128 - CORE_R), project(128 + CORE_R)),
        (project(128 + IN_HALF), project(128 + OUT_HALF)),
    ]
    expected_row = [
        (project(128 - OUT_HALF), project(128 - IN_HALF)),
        (project(128 - CORE_R), project(128 + CORE_R)),
    ]

    for axis, expected in (("x", expected_row), ("y", expected_column)):
        measured = ink_runs(image, axis, centre, background)
        if len(measured) != len(expected):
            raise RuntimeError(
                f"{name}: along {axis} the artwork has {len(measured)} run(s) {measured}, "
                f"but the construction expects {len(expected)} {expected}"
            )
        for (m0, m1), (e0, e1) in zip(measured, expected):
            if abs(m0 - e0) > 1.5 or abs(m1 - e1) > 1.5:
                raise RuntimeError(
                    f"{name}: along {axis} a run is {m0:.1f}..{m1:.1f} but the construction "
                    f"says {e0:.1f}..{e1:.1f} (tolerance 1.5 grid units)"
                )

    # The door must be empty: the only opening in the wall.
    door_middle = int((DOOR_Y0 + DOOR_Y1) / 2 * image.size[0] / GRID)
    door_probe = image.getpixel((int((128 + OUT_HALF) * image.size[0] / GRID) - 6, door_middle))
    if max(abs(c - d) for c, d in zip(door_probe, background)) > 24:
        raise RuntimeError(f"{name}: the door is not open, found {door_probe}")

    print(f"{name}: geometry matches the construction at scale {scale_factor:.2f}")


def assert_adaptive_safe_zone(name: str) -> None:
    """Android crops an adaptive icon to 72 of 108 dp, so the mark must stay
    inside 66,7 % of the canvas or the launcher mask will clip it."""
    image = Image.open(OUT / name).convert("RGBA")
    box = image.getchannel("A").getbbox()
    if box is None:
        raise RuntimeError(f"{name}: the foreground is empty")
    used_w = (box[2] - box[0]) / image.size[0] * 100
    used_h = (box[3] - box[1]) / image.size[1] * 100
    if used_w > 66.8 or used_h > 66.8:
        raise RuntimeError(
            f"{name}: the mark uses {used_w:.1f} % x {used_h:.1f} % of the canvas, "
            "outside Android's 66,7 % safe zone"
        )
    print(f"{name}: safe zone respected, uses {used_w:.1f} % x {used_h:.1f} %")


def assert_lockup_alignment(name: str, background: tuple[int, int, int] = DARK) -> None:
    """The symbol and the wordmark must share one optical centre."""
    image = Image.open(OUT / name).convert("RGB")

    def columns() -> list[int]:
        found = []
        for x in range(image.size[0]):
            if any(
                max(abs(c - d) for c, d in zip(image.getpixel((x, y)), background)) > 30
                for y in range(image.size[1])
            ):
                found.append(x)
        return found

    xs = columns()
    if not xs:
        raise RuntimeError(f"{name}: the lockup is empty")
    gaps = [i for i in range(1, len(xs)) if xs[i] - xs[i - 1] > 8]
    if not gaps:
        raise RuntimeError(f"{name}: the symbol and the wordmark are not separated")
    split = gaps[0]
    symbol_x, word_x = xs[: split + 1], xs[split + 1 :]

    def vertical_centre(lo: int, hi: int) -> float:
        ys = [
            y
            for y in range(image.size[1])
            for x in range(lo, hi)
            if max(abs(c - d) for c, d in zip(image.getpixel((x, y)), background)) > 30
        ]
        return (min(ys) + max(ys)) / 2

    symbol_centre = vertical_centre(symbol_x[0], symbol_x[-1] + 1)
    word_centre = vertical_centre(word_x[0], word_x[-1] + 1)
    offset = abs(symbol_centre - word_centre)
    if offset > 4:
        raise RuntimeError(
            f"{name}: symbol centred at {symbol_centre:.1f} and wordmark at {word_centre:.1f} "
            f"are {offset:.1f} px apart"
        )
    left_margin = symbol_x[0]
    right_margin = image.size[0] - 1 - word_x[-1]
    if abs(left_margin - right_margin) > 12:
        raise RuntimeError(
            f"{name}: margins are unbalanced, left {left_margin} px and right {right_margin} px"
        )
    print(
        f"{name}: lockup aligned, centres {offset:.1f} px apart, "
        f"margins {left_margin}/{right_margin} px"
    )


def compose_size_sheet(icon: Image.Image) -> None:
    """The icon has to survive the launcher grid, so show it at real sizes."""
    sizes = (128, 64, 48, 32, 24)
    width = 64 + sum(size + 24 for size in sizes)
    sheet = Image.new("RGB", (width, 250), LIGHT)
    draw = ImageDraw.Draw(sheet)
    caption = load_font(22)
    x = 32
    for size in sizes:
        sheet.paste(icon.resize((size, size), Image.Resampling.LANCZOS), (x, 40))
        draw.text((x, 190), f"{size} px", fill=LIGHT_INK, font=caption)
        x += size + 24
    draw.text((32, 12), "Detox Umbral — escala real de icono", fill=LIGHT_INK, font=load_font(26))
    sheet.save(OUT / "prueba_tamanos.png")
    print("prueba_tamanos.png: 128, 64, 48, 32 and 24 px")


def compose_comparison(icon: Image.Image) -> None:
    """Put the replaced raster next to the new mark at two sizes."""
    if not OLD_ICON.exists():
        print("prueba_comparativa.png skipped: the previous icon was not found")
        return
    old = Image.open(OLD_ICON).convert("RGBA")
    sheet = Image.new("RGB", (760, 400), LIGHT)
    draw = ImageDraw.Draw(sheet)
    draw.text((32, 16), "Antes y después", fill=LIGHT_INK, font=load_font(28))

    def place(image: Image.Image, x: int, y: int, size: int) -> None:
        thumb = image.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
        backdrop = Image.new("RGB", (size, size), DARK)
        backdrop.paste(thumb, (0, 0), thumb)
        sheet.paste(backdrop, (x, y))

    place(old, 32, 68, 300)
    place(icon, 408, 68, 300)
    draw.text((32, 372), "Antes: raster 1024 px, 48.806 colores", fill=LIGHT_MUTED, font=load_font(18))
    draw.text((408, 372), "Ahora: Umbral, 2 formas vectoriales", fill=LIGHT_MUTED, font=load_font(18))

    small_old = old.resize((72, 72), Image.Resampling.LANCZOS)
    small_new = icon.convert("RGBA").resize((72, 72), Image.Resampling.LANCZOS)
    for label, image, x in (("antes", small_old, 356), ("ahora", small_new, 660)):
        backdrop = Image.new("RGB", (72, 72), DARK)
        backdrop.paste(image, (0, 0), image)
        sheet.paste(backdrop, (x, 260))
        draw.text((x - 4, 340), f"{label} 72 px", fill=LIGHT_MUTED, font=load_font(15))
    sheet.save(OUT / "prueba_comparativa.png")
    print("prueba_comparativa.png: previous vs new at 300 and 72 px")


def compose_monochrome() -> None:
    """One-colour use is the usual failure point, so verify it explicitly."""
    white = Image.open(OUT / "isotipo_blanco.png").convert("RGBA")
    black = Image.open(OUT / "isotipo_negro.png").convert("RGBA")
    sheet = Image.new("RGB", (640, 300), LIGHT)
    draw = ImageDraw.Draw(sheet)
    dark_tile = Image.new("RGB", (256, 256), DARK)
    dark_tile.paste(white, (0, 0), white)
    sheet.paste(dark_tile, (32, 44))
    light_tile = Image.new("RGB", (256, 256), LIGHT)
    light_tile.paste(black, (0, 0), black)
    sheet.paste(light_tile, (352, 44))
    draw.text((32, 12), "Un solo color", fill=LIGHT_INK, font=load_font(28))
    draw.text((32, 308), "Blanco sobre carbon", fill=LIGHT_MUTED, font=load_font(16))
    draw.text((352, 308), "Negro sobre claro", fill=LIGHT_MUTED, font=load_font(16))
    sheet.save(OUT / "prueba_monocromo.png")
    print("prueba_monocromo.png: white on charcoal and black on light")


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    channels = []
    for value in rgb:
        v = value / 255
        channels.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    r, g, b = channels
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = relative_luminance(a), relative_luminance(b)
    lighter, darker = max(la, lb), min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)


def compose_contrast() -> None:
    pairs = (
        ("Salvia sobre carbon", SAGE, DARK, True),
        ("Salvia sobre tarjeta", SAGE, (21, 30, 26), True),
        ("Salvia suave sobre carbon", SAGE_SOFT, DARK, True),
        ("Verde profundo sobre claro", DEEP, LIGHT, True),
        ("Verde profundo sobre claro alt", DEEP, (234, 240, 234), True),
        ("Tinta sobre carbon", INK, DARK, True),
        ("Cian del logo anterior", (92, 205, 233), (2, 2, 2), False),
    )
    row_h = 56
    sheet = Image.new("RGB", (860, 60 + row_h * len(pairs) + 70), LIGHT)
    draw = ImageDraw.Draw(sheet)
    draw.text((28, 16), "Contraste WCAG del símbolo", fill=LIGHT_INK, font=load_font(28))
    y = 64
    for label, foreground, background, passes in pairs:
        draw.rectangle((28, y, 188, y + 40), fill=background)
        draw.rectangle((88, y + 6, 128, y + 34), fill=foreground)
        draw.text((208, y + 8), label, fill=LIGHT_INK, font=load_font(20))
        ratio = contrast(foreground, background)
        ok = ratio >= 4.5
        draw.text(
            (640, y + 8),
            f"{ratio:.2f}:1  {'AA' if ok else 'bajo'}",
            fill=DEEP if ok else (170, 90, 90),
            font=load_font(20),
        )
        y += row_h
    draw.text(
        (28, y + 12),
        "El símbolo se usa a 3:1 o más sobre cada fondo donde aparece; el cian anterior aplanaba a negro en escala de grises.",
        fill=LIGHT_MUTED,
        font=load_font(17),
    )
    sheet.save(OUT / "prueba_contraste.png")
    print("prueba_contraste.png: contrast ratios per background")


if __name__ == "__main__":
    assert_door_is_derived()
    render_svgs()
    assert_mark_geometry("icono_app.png", 1.0)
    assert_mark_geometry("icono_app_claro.png", 1.0, LIGHT)
    assert_mark_geometry("icono_app_alterno.png", 1.0, (16, 25, 22))
    assert_adaptive_safe_zone("icono_adaptable_frente.png")
    assert_lockup_alignment("logo_horizontal_oscuro_fondo.png")
    assert_lockup_alignment("logo_horizontal_claro.png", LIGHT)
    icon = Image.open(OUT / "icono_app.png").convert("RGB")
    compose_size_sheet(icon)
    compose_comparison(icon)
    compose_monochrome()
    compose_contrast()
