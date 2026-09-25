"""Generate editable SVG concepts and Detox logo exports.

Run from the repository root with: python docs/brand/detox-logo/generate.py
"""

from pathlib import Path
from xml.sax.saxutils import escape


OUT = Path(__file__).resolve().parent
CONCEPT_BODIES: dict[str, str] = {}
DARK = "#0B110F"
LIGHT = "#F4F7F3"
TEAL = "#8BC7AE"
DEEP = "#426A59"
INK = "#E8EDEA"
LIGHT_INK = "#202B26"


def svg(view_box: str, body: str, title: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{view_box}" role="img" aria-label="{escape(title)}">\n'
        f'  <title>{escape(title)}</title>\n{body}\n</svg>\n'
    )


def save(name: str, content: str) -> None:
    (OUT / name).write_text(content, encoding="utf-8")


def mark_d(color: str) -> str:
    # A deliberate gap in the top edge leaves a quiet pause in the D/progress ring.
    return f'''  <g fill="none" stroke="{color}" stroke-width="17" stroke-linecap="round" stroke-linejoin="round">
    <path d="M64 51V205H113C161 205 193 173 193 128C193 95 175 68 146 57"/>
    <path d="M64 51H104"/>
  </g>
  <circle cx="127" cy="128" r="8" fill="{color}"/>'''


def concept_icon(name: str, title: str, body: str) -> None:
    CONCEPT_BODIES[name] = body
    content = svg(
        "0 0 256 256",
        f'  <rect width="256" height="256" rx="54" fill="{DARK}"/>\n{body}',
        title,
    )
    save(f"concepto_{name}.svg", content)


concept_icon("01_d_anillo", "D Anillo: enfoque y progreso", mark_d(TEAL))

concept_icon(
    "02_pausa_orbital",
    "Pausa orbital: control consciente del tiempo",
    f'''  <circle cx="128" cy="128" r="73" fill="none" stroke="{DEEP}" stroke-width="16"/>
  <path d="M128 55A73 73 0 1 1 55 128" fill="none" stroke="{TEAL}" stroke-width="16" stroke-linecap="round"/>
  <rect x="102" y="98" width="16" height="60" rx="8" fill="{TEAL}"/>
  <rect x="138" y="98" width="16" height="60" rx="8" fill="{TEAL}"/>''',
)

concept_icon(
    "03_foco",
    "Foco: atención en lo esencial",
    f'''  <g fill="none" stroke="{TEAL}" stroke-width="16" stroke-linecap="round" stroke-linejoin="round">
    <path d="M100 57H66Q57 57 57 66V100"/>
    <path d="M156 57H190Q199 57 199 66V100"/>
    <path d="M57 156V190Q57 199 66 199H100"/>
    <path d="M199 156V190Q199 199 190 199H156"/>
  </g>
  <circle cx="128" cy="128" r="12" fill="{TEAL}"/>''',
)

concept_icon(
    "04_equilibrio",
    "Equilibrio: espacio entre actividad y descanso",
    f'''  <g fill="none" stroke="{TEAL}" stroke-width="17" stroke-linecap="round">
    <path d="M62 96C91 54 165 54 194 96"/>
    <path d="M62 160C91 202 165 202 194 160"/>
  </g>
  <path d="M94 128H162" fill="none" stroke="{TEAL}" stroke-width="17" stroke-linecap="round"/>''',
)

concept_icon(
    "05_ruido_a_calma",
    "Ruido a calma: menos estímulos digitales",
    f'''  <g fill="{TEAL}">
    <rect x="58" y="76" width="18" height="104" rx="9"/>
    <rect x="90" y="91" width="18" height="74" rx="9"/>
    <rect x="122" y="106" width="18" height="44" rx="9"/>
    <circle cx="176" cy="128" r="12"/>
  </g>''',
)


save("isotipo.svg", svg("0 0 256 256", mark_d(DEEP), "Detox: isotipo D Anillo"))
save("isotipo_oscuro.svg", svg("0 0 256 256", mark_d(TEAL), "Detox: isotipo sobre fondo oscuro"))
save(
    "app_icon.svg",
    svg(
        "0 0 256 256",
        f'  <rect width="256" height="256" fill="{DARK}"/>\n{mark_d(TEAL)}',
        "Detox: icono de aplicación",
    ),
)
save(
    "app_icon_claro.svg",
    svg(
        "0 0 256 256",
        f'  <rect width="256" height="256" fill="{LIGHT}"/>\n{mark_d(DEEP)}',
        "Detox: icono de aplicación claro",
    ),
)
save(
    "adaptive_foreground.svg",
    svg(
        "0 0 256 256",
        mark_d(TEAL),
        "Detox: primer plano transparente para icono adaptable",
    ),
)


def logo_body(symbol_color: str, text_color: str, background: str | None = None) -> str:
    bg = f'  <rect width="760" height="214" fill="{background}"/>\n' if background else ""
    return (
        bg
        + f'  <g transform="translate(0 4) scale(.8)">\n{mark_d(symbol_color)}\n  </g>\n'
        + f'  <text x="207" y="149" fill="{text_color}" font-family="Segoe UI, Arial, sans-serif" '
        'font-size="110" font-weight="600" letter-spacing="-5">Detox</text>'
    )


save("logo_principal.svg", svg("0 0 760 214", logo_body(TEAL, INK), "Detox: logo principal"))
save(
    "logo_fondo_oscuro.svg",
    svg("0 0 760 214", logo_body(TEAL, INK, DARK), "Detox: logo sobre fondo oscuro"),
)
save(
    "logo_fondo_claro.svg",
    svg("0 0 760 214", logo_body(DEEP, LIGHT_INK, LIGHT), "Detox: logo sobre fondo claro"),
)


cards = [
    ("01_d_anillo", "01 / D Anillo", "Letra D + anillo abierto", "Identidad, progreso y espacio mental."),
    ("02_pausa_orbital", "02 / Pausa orbital", "Pausa dentro del tiempo", "Detener el impulso de abrir el móvil."),
    ("03_foco", "03 / Foco", "Marco de concentración", "Atención dirigida a lo esencial."),
    ("04_equilibrio", "04 / Equilibrio", "Dos curvas en balance", "Alternancia sana entre uso y descanso."),
    ("05_ruido_a_calma", "05 / Ruido a calma", "Señal que disminuye", "Menos estímulos, más claridad."),
]

board = [
    f'  <rect width="1600" height="1060" fill="{LIGHT}"/>',
    f'  <text x="72" y="94" fill="{LIGHT_INK}" font-family="Segoe UI, Arial, sans-serif" font-size="48" font-weight="600">Detox</text>',
    f'  <text x="72" y="140" fill="#68746C" font-family="Segoe UI, Arial, sans-serif" font-size="24">Cinco rutas para una relación más clara con la tecnología</text>',
]
for index, (filename, label, idea, reason) in enumerate(cards):
    col = index % 3
    row = index // 3
    x = 72 + col * 500
    y = 204 + row * 402
    board.extend(
        [
            f'  <rect x="{x}" y="{y}" width="460" height="362" rx="28" fill="#FFFFFF"/>',
            f'  <g transform="translate({x+28} {y+28}) scale(.836)">'
            f'<rect width="256" height="256" rx="54" fill="{DARK}"/>{CONCEPT_BODIES[filename]}</g>',
            f'  <text x="{x+266}" y="{y+90}" fill="{LIGHT_INK}" font-family="Segoe UI, Arial, sans-serif" font-size="21" font-weight="600">{escape(label)}</text>',
            f'  <text x="{x+266}" y="{y+131}" fill="#68746C" font-family="Segoe UI, Arial, sans-serif" font-size="17">{escape(idea)}</text>',
            f'  <text x="{x+28}" y="{y+294}" fill="{LIGHT_INK}" font-family="Segoe UI, Arial, sans-serif" font-size="21">{escape(reason)}</text>',
            f'  <text x="{x+28}" y="{y+330}" fill="#68746C" font-family="Segoe UI, Arial, sans-serif" font-size="17">Icono de app: una forma, sin texto ni detalles finos.</text>',
        ]
    )
save("conceptos.svg", svg("0 0 1600 1060", "\n".join(board), "Detox: cinco conceptos de logo"))

print(f"Generated {len(list(OUT.glob('*.svg')))} SVG files in {OUT}")
