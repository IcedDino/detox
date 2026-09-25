"""Generate the redesigned Detox icon system as editable SVG files.

Run from the repository root with:
    python docs/brand/detox-icon/generate.py

Every shape is built from numbers on a 256 x 256 grid, so the construction can
be re-derived or corrected without redrawing anything by hand.
"""

from __future__ import annotations

import math
from pathlib import Path
from xml.sax.saxutils import escape


OUT = Path(__file__).resolve().parent

# Palette copied from lib/theme/app_theme.dart so the mark matches the live UI.
DARK = "#0B110F"
DARK_ALT = "#101916"
CARD = "#151E1A"
LIGHT = "#F4F7F3"
LIGHT_ALT = "#EAF0EA"
SAGE = "#8BC7AE"
SAGE_SOFT = "#B7DDCA"
DEEP = "#426A59"
INK = "#E8EDEA"
MUTED = "#8C988F"
LIGHT_INK = "#202B26"
LIGHT_MUTED = "#68746C"
GRID = "#D3DED6"
EDGE_BLUE = "#5CCDE9"  # measured average of the icon being replaced

FONT = "Segoe UI, Arial, Helvetica, sans-serif"

# --- Direction A geometry ("Umbral") ---------------------------------------
OUT_HALF = 88.0   # half size of the room
OUT_R = 46.0      # outer corner radius
WALL = 44.0       # wall thickness
IN_HALF = OUT_HALF - WALL
IN_R = 22.0       # corner radius of the room; tighter than the outer one so the
                  # wall keeps a steady weight as it turns the corner

# The door's height is derived, never chosen. The inner rounded rect has a
# straight right edge only between its two corner arcs, that is from
# 128 - (IN_HALF - IN_R) to 128 + (IN_HALF - IN_R). A door taller than that puts
# its straight left edge across a corner arc and leaves a hairline sliver of ink
# hanging inside the opening — a burr that reads as a bad cut. Deriving the door
# from the flat edge removes that whole class of defect, and it makes the opening
# exactly as tall as the wall is thick.
DOOR_HALF = IN_HALF - IN_R
DOOR_Y0 = 128 - DOOR_HALF
DOOR_Y1 = 128 + DOOR_HALF
CORE_R = 22.0     # the core kept inside
SAFE_SCALE = 0.96  # keeps the silhouette inside Android's adaptive safe zone


def svg(width: int, height: int, view_box: str, body: str, title: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        f'width="{width}" height="{height}" viewBox="{view_box}" '
        f'role="img" aria-label="{escape(title)}">\n'
        f"  <title>{escape(title)}</title>\n{body}\n</svg>\n"
    )


def save(name: str, content: str) -> None:
    (OUT / name).write_text(content, encoding="utf-8")


def rr(x0: float, y0: float, x1: float, y1: float, r: float) -> str:
    """A rounded rectangle as one clockwise subpath."""
    r = max(0.0, min(r, (x1 - x0) / 2, (y1 - y0) / 2))
    if r == 0:
        return f"M {x0:.2f} {y0:.2f} H {x1:.2f} V {y1:.2f} H {x0:.2f} Z"
    return (
        f"M {x0 + r:.2f} {y0:.2f} H {x1 - r:.2f} "
        f"A {r:.2f} {r:.2f} 0 0 1 {x1:.2f} {y0 + r:.2f} V {y1 - r:.2f} "
        f"A {r:.2f} {r:.2f} 0 0 1 {x1 - r:.2f} {y1:.2f} H {x0 + r:.2f} "
        f"A {r:.2f} {r:.2f} 0 0 1 {x0:.2f} {y1 - r:.2f} V {y0 + r:.2f} "
        f"A {r:.2f} {r:.2f} 0 0 1 {x0 + r:.2f} {y0:.2f} Z"
    )


def circle_subpath(cx: float, cy: float, r: float) -> str:
    """A full circle as a path subpath, so it can share a fill rule."""
    return (
        f"M {cx - r:.2f} {cy:.2f} "
        f"A {r:.2f} {r:.2f} 0 1 1 {cx + r:.2f} {cy:.2f} "
        f"A {r:.2f} {r:.2f} 0 1 1 {cx - r:.2f} {cy:.2f} Z"
    )


def polar(r: float, deg: float, cx: float = 128.0, cy: float = 128.0) -> tuple[float, float]:
    a = math.radians(deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def polygon(points: list[tuple[float, float]]) -> str:
    head = f"M {points[0][0]:.2f} {points[0][1]:.2f}"
    return head + "".join(f" L {x:.2f} {y:.2f}" for x, y in points[1:]) + " Z"


# ---------------------------------------------------------------------------
# Direction A: "Umbral" (the threshold)
#
# A rounded-square room. The squircle echoes the rounded cards the whole app is
# built from; the single door is the only place the outside gets in; the core
# stays inside. Three subpaths on one even-odd fill produce the wall, the room
# and the opening, so the silhouette never depends on a background colour.
# ---------------------------------------------------------------------------
UMBRAL_PATH = " ".join(
    (
        rr(128 - OUT_HALF, 128 - OUT_HALF, 128 + OUT_HALF, 128 + OUT_HALF, OUT_R),
        rr(128 - IN_HALF, 128 - IN_HALF, 128 + IN_HALF, 128 + IN_HALF, IN_R),
        rr(128 + IN_HALF, DOOR_Y0, 128 + OUT_HALF, DOOR_Y1, 0),
    )
)


def umbral(color: str, with_core: bool = True) -> str:
    parts = [f'  <path d="{UMBRAL_PATH}" fill-rule="evenodd" fill="{color}"/>']
    if with_core:
        parts.append(f'  <circle cx="128" cy="128" r="{CORE_R}" fill="{color}"/>')
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Direction B: "Ruido a calma" (noise into calm)
# Three bars of decreasing height resolving into a single resting point.
# ---------------------------------------------------------------------------
def ruido_a_calma(color: str) -> str:
    parts = []
    for x, height in ((48, 128), (92, 92), (136, 56)):
        y0 = 128 - height / 2
        parts.append(
            f'  <rect x="{x}" y="{y0:.2f}" width="24" height="{height:.2f}" '
            f'rx="12" fill="{color}"/>'
        )
    parts.append(f'  <circle cx="196" cy="128" r="16" fill="{color}"/>')
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Direction C: the same idea in a circular container, as a safer alternative.
# ---------------------------------------------------------------------------
DOOR_DEG = 26.0
UMBRAL_CIRCULAR_PATH = " ".join(
    (
        circle_subpath(128, 128, OUT_HALF),
        circle_subpath(128, 128, IN_HALF),
        polygon(
            (
                polar(IN_HALF, -DOOR_DEG),
                polar(OUT_HALF + 8, -DOOR_DEG),
                polar(OUT_HALF + 8, DOOR_DEG),
                polar(IN_HALF, DOOR_DEG),
            )
        ),
    )
)


def umbral_circular(color: str, with_core: bool = True) -> str:
    parts = [f'  <path d="{UMBRAL_CIRCULAR_PATH}" fill-rule="evenodd" fill="{color}"/>']
    if with_core:
        parts.append(f'  <circle cx="128" cy="128" r="{CORE_R}" fill="{color}"/>')
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Composition helpers
# ---------------------------------------------------------------------------
def centred(body: str, scale: float) -> str:
    """Scale a 256-grid body about its centre."""
    return (
        f'  <g transform="translate(128 128) scale({scale:.4f}) translate(-128 -128)">\n'
        f"{body}\n  </g>"
    )


# Full-bleed icons keep the mark at 1.0, which leaves 40 units of margin and
# puts the silhouette at 68,75 % of the canvas — the usual weight for a
# launcher tile. Only the adaptive foreground is scaled down, to 66 %.
ICON_SCALE = 1.0


def tile(body: str, background: str, scale: float = ICON_SCALE) -> str:
    return f'  <rect width="256" height="256" fill="{background}"/>\n{centred(body, scale)}'


# The lockup is cropped to its own content: the symbol's ink starts at 44.8 and
# the wordmark ends near 502.5, so 548 x 220 leaves equal margins and puts both
# the symbol and the cap height of the text on the canvas centre (110).
LOGO_W, LOGO_H = 548, 220
LOGO_SYMBOL_Y = 17.8  # aligns the symbol's centre with the text's cap-height centre


def logo_horizontal(body: str, text_color: str, background: str | None = None) -> str:
    bg = (
        f'  <rect width="{LOGO_W}" height="{LOGO_H}" fill="{background}"/>\n'
        if background
        else ""
    )
    return (
        bg
        + f'  <g transform="translate(16 {LOGO_SYMBOL_Y}) scale(.72)">\n'
        + body
        + "\n  </g>\n"
        + f'  <text x="228" y="148" fill="{text_color}" font-family="{FONT}" '
        'font-size="110" font-weight="600" letter-spacing="-5">Detox</text>'
    )


MARK_DARK = umbral(SAGE)
MARK_LIGHT = umbral(DEEP)

# --- Symbol and application icon -------------------------------------------
save(
    "isotipo_sobre_oscuro.svg",
    svg(256, 256, "0 0 256 256", MARK_DARK, "Detox: simbolo Umbral sobre fondo oscuro"),
)
save(
    "isotipo_sobre_claro.svg",
    svg(256, 256, "0 0 256 256", MARK_LIGHT, "Detox: simbolo Umbral sobre fondo claro"),
)
save(
    "isotipo_blanco.svg",
    svg(256, 256, "0 0 256 256", umbral("#FFFFFF"), "Detox: simbolo Umbral en blanco"),
)
save(
    "isotipo_negro.svg",
    svg(256, 256, "0 0 256 256", umbral("#0B110F"), "Detox: simbolo Umbral en negro"),
)

save(
    "icono_app.svg",
    svg(512, 512, "0 0 256 256", tile(MARK_DARK, DARK), "Detox: icono de aplicacion"),
)
save(
    "icono_app_claro.svg",
    svg(512, 512, "0 0 256 256", tile(MARK_LIGHT, LIGHT), "Detox: icono de aplicacion claro"),
)
save(
    "icono_app_alterno.svg",
    svg(
        512,
        512,
        "0 0 256 256",
        tile(MARK_DARK, DARK_ALT),
        "Detox: icono de aplicacion sobre carbon elevado",
    ),
)
save(
    "icono_adaptable_frente.svg",
    svg(
        512,
        512,
        "0 0 256 256",
        centred(MARK_DARK, SAFE_SCALE),
        "Detox: primer plano transparente para icono adaptable",
    ),
)
# Android 13 draws themed icons by tinting a single-colour silhouette, so this
# layer is flat white and uses the same safe-zone scale as the foreground.
save(
    "icono_adaptable_monocromo.svg",
    svg(
        512,
        512,
        "0 0 256 256",
        centred(umbral("#FFFFFF"), SAFE_SCALE),
        "Detox: capa monocroma para iconos tematizados de Android 13",
    ),
)

# --- Lockups ---------------------------------------------------------------
LOGO_BOX = f"0 0 {LOGO_W} {LOGO_H}"
PNG_W, PNG_H = LOGO_W * 2, LOGO_H * 2

save(
    "logo_horizontal_oscuro.svg",
    svg(PNG_W, PNG_H, LOGO_BOX, logo_horizontal(MARK_DARK, INK), "Detox: logo sobre fondo oscuro"),
)
save(
    "logo_horizontal_oscuro_fondo.svg",
    svg(
        PNG_W,
        PNG_H,
        LOGO_BOX,
        logo_horizontal(MARK_DARK, INK, DARK),
        "Detox: logo sobre fondo oscuro solido",
    ),
)
save(
    "logo_horizontal_claro.svg",
    svg(
        PNG_W,
        PNG_H,
        LOGO_BOX,
        logo_horizontal(MARK_LIGHT, LIGHT_INK, LIGHT),
        "Detox: logo sobre fondo claro",
    ),
)

# --- Alternatives ----------------------------------------------------------
save(
    "alternativa_b_ruido_a_calma.svg",
    svg(
        512,
        512,
        "0 0 256 256",
        tile(ruido_a_calma(SAGE), DARK),
        "Detox: alternativa B, ruido a calma",
    ),
)
save(
    "alternativa_c_umbral_circular.svg",
    svg(
        512,
        512,
        "0 0 256 256",
        tile(umbral_circular(SAGE), DARK),
        "Detox: alternativa C, Umbral circular",
    ),
)

# --- Construction mesh -----------------------------------------------------
mesh: list[str] = [f'  <rect width="256" height="256" fill="{LIGHT}"/>']
for step in range(0, 257, 16):
    weight = 0.5 if step % 64 else 0.9
    opacity = 0.55 if step % 64 else 1.0
    mesh.append(
        f'  <line x1="{step}" y1="0" x2="{step}" y2="256" stroke="{GRID}" '
        f'stroke-width="{weight}" opacity="{opacity}"/>'
    )
    mesh.append(
        f'  <line x1="0" y1="{step}" x2="256" y2="{step}" stroke="{GRID}" '
        f'stroke-width="{weight}" opacity="{opacity}"/>'
    )
mesh.append(
    f'  <line x1="128" y1="8" x2="128" y2="248" stroke="{MUTED}" stroke-width="0.5" '
    'stroke-dasharray="4 4"/>'
)
mesh.append(
    f'  <line x1="8" y1="128" x2="248" y2="128" stroke="{MUTED}" stroke-width="0.5" '
    'stroke-dasharray="4 4"/>'
)
mesh.append(
    f'  <path d="{rr(128 - OUT_HALF, 128 - OUT_HALF, 128 + OUT_HALF, 128 + OUT_HALF, OUT_R)}" '
    f'fill="none" stroke="{DEEP}" stroke-width="0.8"/>'
)
mesh.append(
    f'  <path d="{rr(128 - IN_HALF, 128 - IN_HALF, 128 + IN_HALF, 128 + IN_HALF, IN_R)}" '
    f'fill="none" stroke="{DEEP}" stroke-width="0.6" stroke-dasharray="3 2"/>'
)
mesh.append(
    f'  <rect x="{128 + IN_HALF}" y="{DOOR_Y0}" width="{OUT_HALF - IN_HALF}" '
    f'height="{DOOR_Y1 - DOOR_Y0}" fill="none" stroke="{EDGE_BLUE}" stroke-width="1"/>'
)
mesh.append(
    f'  <circle cx="128" cy="128" r="{CORE_R}" fill="none" stroke="{DEEP}" '
    'stroke-width="0.6" stroke-dasharray="3 2"/>'
)
# paint-order draws the halo first, so a dimension stays readable both on the
# grid and on top of the artwork itself.
labels = [
    (128, 34, "88"),
    (60, 130, "44"),
    (66, 66, "R46"),
    (99, 99, "R22"),
    (194, 127, "44x44"),
]
for lx, ly, text in labels:
    mesh.append(
        f'  <text x="{lx}" y="{ly}" fill="{DEEP}" stroke="{LIGHT}" stroke-width="2.4" '
        f'paint-order="stroke" font-family="{FONT}" font-size="7.5" font-weight="600" '
        f'text-anchor="middle">{text}</text>'
    )
mesh.append(f'  <rect x="8" y="226" width="240" height="30" fill="{LIGHT}"/>')
legend = (
    "malla 256 x 256  -  muro 44  -  esquina exterior R46  -  esquina interior R22",
    "puerta 44 x 44 centrada  -  nucleo R22  -  margen libre minimo 16  -  trazo minimo 22",
)
for index, line in enumerate(legend):
    mesh.append(
        f'  <text x="128" y="{240 + index * 11}" fill="{LIGHT_MUTED}" font-family="{FONT}" '
        f'font-size="6" text-anchor="middle">{line}</text>'
    )
save(
    "malla_construccion.svg",
    svg(1024, 1024, "0 0 256 256", "\n".join(mesh), "Detox: malla de construccion del simbolo"),
)

# --- Direction board -------------------------------------------------------
BOARD_W, BOARD_H = 1400, 900
board: list[str] = [f'  <rect width="{BOARD_W}" height="{BOARD_H}" fill="{LIGHT}"/>']
board.append(
    f'  <text x="64" y="86" fill="{LIGHT_INK}" font-family="{FONT}" font-size="46" '
    'font-weight="600">Detox — rediseño del símbolo</text>'
)
board.append(
    f'  <text x="64" y="128" fill="{LIGHT_MUTED}" font-family="{FONT}" font-size="22">'
    "Tres rutas construidas con la paleta real de la app, sin letras, sin degradados y sin brillos.</text>"
)
board.append(
    f'  <text x="64" y="162" fill="{LIGHT_MUTED}" font-family="{FONT}" font-size="18">'
    "Antes: mapa de bits de 1024 px, 48.806 colores, media #5CCDE9 sobre #020202. Ninguna forma se podía corregir ni escalar.</text>"
)

panels = [
    (
        "A",
        MARK_DARK,
        "Umbral",
        "Elegida",
        (
            "Una sala de esquinas redondeadas",
            "—el mismo lenguaje que las tarjetas",
            "de la app— con una sola puerta en",
            "el muro y el núcleo dentro. El",
            "squircle no se confunde con otro",
            "anillo y aguanta la máscara del",
            "sistema sin perder el aire.",
        ),
    ),
    (
        "B",
        ruido_a_calma(SAGE),
        "Ruido a calma",
        "Alternativa",
        (
            "Tres barras que bajan de altura",
            "hasta un punto de reposo. Cuenta",
            "muy bien la promesa del producto,",
            "pero su silueta horizontal es",
            "menos propia como icono de app y",
            "compite con el texto en el lockup.",
        ),
    ),
    (
        "C",
        umbral_circular(SAGE),
        "Umbral circular",
        "Alternativa",
        (
            "La misma idea con contenedor",
            "circular. Es la opción más segura",
            "y la más parecida a lo que ya",
            "existe en el mercado de bienestar",
            "digital, por eso pierde algo de",
            "carácter frente a A.",
        ),
    ),
]

for index, (letter, body, title, tag, lines) in enumerate(panels):
    x = 64 + index * 436
    y = 208
    board.append(
        f'  <rect x="{x}" y="{y}" width="404" height="560" rx="28" fill="#FFFFFF"/>'
    )
    board.append(f'  <g transform="translate({x + 34} {y + 34}) scale(.78)">')
    board.append(f'  <rect width="256" height="256" rx="52" fill="{DARK}"/>')
    board.append(centred(body, 0.76))
    board.append("  </g>")
    board.append(
        f'  <text x="{x + 34}" y="{y + 336}" fill="{LIGHT_INK}" font-family="{FONT}" '
        f'font-size="32" font-weight="600">{letter} · {escape(title)}</text>'
    )
    board.append(
        f'  <text x="{x + 34}" y="{y + 370}" fill="{DEEP}" font-family="{FONT}" '
        f'font-size="17" font-weight="600" letter-spacing="1.4">{escape(tag.upper())}</text>'
    )
    for i, line in enumerate(lines):
        board.append(
            f'  <text x="{x + 34}" y="{y + 410 + i * 28}" fill="{LIGHT_MUTED}" '
            f'font-family="{FONT}" font-size="18">{escape(line)}</text>'
        )

board.append(
    f'  <text x="64" y="{BOARD_H - 44}" fill="{LIGHT_MUTED}" font-family="{FONT}" font-size="18">'
    "Retícula de 256 × 256 · muro 44 · esquina exterior 46 · puerta 48 × 44 · núcleo 22 · trazo mínimo 22 unidades (2,75 px a 32 px).</text>"
)
save(
    "tablero_direcciones.svg",
    svg(BOARD_W, BOARD_H, f"0 0 {BOARD_W} {BOARD_H}", "\n".join(board), "Detox: tablero de direcciones"),
)

print(f"Generated {len(list(OUT.glob('*.svg')))} SVG files in {OUT}")
