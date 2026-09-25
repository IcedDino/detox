"""Generate the legal documents in the two formats the project needs.

Run from the repository root with:
    python docs/legal/generar.py

It writes:

- `docs/legal/<name>.html` — a standalone page, for the public URL that Google
  Play requires in the store listing.
- `assets/legal/<name>.json` — a structured version that the app renders with
  native widgets, so tapping a link inside Detox never leaves the app.

Both come from the same `.md` files, which stay the single source of truth. The
Markdown is parsed once into a list of blocks and each target renders those
blocks, so the page and the in-app text cannot drift apart.

The parser covers only the constructs these documents use: headings, paragraphs,
bullet and numbered lists, tables, blockquotes, horizontal rules, bold and
inline code. If a document needs something else, add it here rather than editing
the generated files by hand.
"""

from __future__ import annotations

import html
import json
import re
from pathlib import Path


# docs/legal -> docs -> repository root.
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
ASSETS = ROOT / "assets" / "legal"

# The asset destination lives outside this folder, so a wrong path would write
# somewhere else entirely instead of failing. Anchor it to the project first.
if not (ROOT / "pubspec.yaml").exists():
    raise SystemExit(
        f"{ROOT} does not look like the project root (no pubspec.yaml). "
        "Refusing to write outside docs/legal."
    )

DOCUMENTS = {
    "aviso-de-privacidad": "Aviso de Privacidad — Detox",
    "terminos-y-condiciones": "Términos y Condiciones — Detox",
}

# Palette from lib/theme/app_theme.dart so the published pages match the app.
STYLE = """
:root {
  color-scheme: light dark;
  --bg: #F4F7F3;
  --surface: #FFFFFF;
  --text: #202B26;
  --muted: #68746C;
  --accent: #426A59;
  --border: rgba(32, 43, 38, 0.10);
  --quote: #EAF0EA;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0B110F;
    --surface: #151E1A;
    --text: #E8EDEA;
    --muted: #8C988F;
    --accent: #8BC7AE;
    --border: rgba(255, 255, 255, 0.08);
    --quote: #101916;
  }
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: "Segoe UI", -apple-system, BlinkMacSystemFont, Roboto, Arial, sans-serif;
  font-size: 17px;
  line-height: 1.65;
}
main { max-width: 760px; margin: 0 auto; padding: 56px 24px 96px; }
h1 { font-size: 2rem; line-height: 1.2; letter-spacing: -0.02em; margin: 0 0 1.5rem; }
h2 {
  font-size: 1.25rem;
  letter-spacing: -0.01em;
  margin: 2.75rem 0 0.75rem;
  padding-top: 1.25rem;
  border-top: 1px solid var(--border);
}
h3 { font-size: 1.05rem; margin: 1.75rem 0 0.5rem; }
p, li { margin: 0.75rem 0; }
ul, ol { padding-left: 1.4rem; }
li > p { margin: 0; }
a { color: var(--accent); }
strong { font-weight: 600; }
code {
  font-family: Consolas, Menlo, monospace;
  font-size: 0.9em;
  background: var(--quote);
  padding: 0.1em 0.4em;
  border-radius: 4px;
  word-break: break-word;
}
hr { border: 0; border-top: 1px solid var(--border); margin: 2.5rem 0; }
blockquote {
  margin: 1.5rem 0;
  padding: 1rem 1.25rem;
  background: var(--quote);
  border-left: 3px solid var(--accent);
  border-radius: 0 8px 8px 0;
}
blockquote p { margin: 0.4rem 0; }
table {
  width: 100%;
  border-collapse: collapse;
  margin: 1.5rem 0;
  font-size: 0.94rem;
  display: block;
  overflow-x: auto;
}
th, td {
  text-align: left;
  vertical-align: top;
  padding: 0.7rem 0.8rem;
  border-bottom: 1px solid var(--border);
}
th {
  font-weight: 600;
  color: var(--muted);
  font-size: 0.82rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
tbody tr:last-child td { border-bottom: 0; }
@media (min-width: 620px) { table { display: table; } }
""".strip()


# --- Markdown parsing -------------------------------------------------------
def split_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def list_item(lines: list[str], index: int) -> tuple[str, int]:
    """Read one list item, joining its indented continuation lines.

    A bold span wrapped across two lines inside an item is common in prose.
    Without this the continuation line falls out of the list and the span is
    left half-converted, which the guard at the end of this file would catch.
    """
    marker = re.match(r"^(?:- |\d+\.\s+)(.*)$", lines[index].strip())
    parts = [marker.group(1)]
    index += 1
    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        if not stripped or not line[:1].isspace():
            break
        if re.match(r"^(?:- |\d+\.\s)", stripped):
            break
        if stripped.startswith(("|", "#", ">")) or stripped == "---":
            break
        parts.append(stripped)
        index += 1
    return " ".join(parts), index


def parse(markdown: str) -> list[dict]:
    lines = markdown.splitlines()
    blocks: list[dict] = []
    paragraph: list[str] = []
    index = 0

    def flush() -> None:
        if paragraph:
            blocks.append({"type": "paragraph", "text": " ".join(paragraph)})
            paragraph.clear()

    while index < len(lines):
        stripped = lines[index].strip()

        if not stripped:
            flush()
            index += 1
            continue

        if stripped.startswith("|") and index + 1 < len(lines) and set(
            lines[index + 1].strip()
        ) <= set("|-: "):
            flush()
            header = split_row(stripped)
            index += 2
            rows = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                rows.append(split_row(lines[index]))
                index += 1
            blocks.append({"type": "table", "header": header, "rows": rows})
            continue

        if stripped == "---":
            flush()
            blocks.append({"type": "rule"})
            index += 1
            continue

        heading = re.match(r"^(#{1,3})\s+(.*)$", stripped)
        if heading:
            flush()
            blocks.append(
                {
                    "type": "heading",
                    "level": len(heading.group(1)),
                    "text": heading.group(2),
                }
            )
            index += 1
            continue

        if stripped.startswith("- "):
            flush()
            items = []
            while index < len(lines) and lines[index].strip().startswith("- "):
                text, index = list_item(lines, index)
                items.append(text)
            blocks.append({"type": "list", "ordered": False, "items": items})
            continue

        if stripped.startswith("> "):
            flush()
            quote = []
            while index < len(lines) and lines[index].strip().startswith("> "):
                quote.append(lines[index].strip()[2:])
                index += 1
            blocks.append({"type": "quote", "text": " ".join(quote)})
            continue

        if re.match(r"^\d+\.\s", stripped):
            flush()
            items = []
            while index < len(lines) and re.match(r"^\d+\.\s", lines[index].strip()):
                text, index = list_item(lines, index)
                items.append(text)
            blocks.append({"type": "list", "ordered": True, "items": items})
            continue

        paragraph.append(stripped)
        index += 1

    flush()
    return blocks


# --- HTML rendering ---------------------------------------------------------
def inline_html(text: str) -> str:
    out = html.escape(text, quote=False)
    out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"`(.+?)`", r"<code>\1</code>", out)
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', out)


def render_html(blocks: list[dict]) -> str:
    out: list[str] = []
    for block in blocks:
        kind = block["type"]
        if kind == "heading":
            level = block["level"]
            out.append(f"<h{level}>{inline_html(block['text'])}</h{level}>")
        elif kind == "paragraph":
            out.append(f"<p>{inline_html(block['text'])}</p>")
        elif kind == "list":
            tag = "ol" if block["ordered"] else "ul"
            out.append(f"<{tag}>")
            out.extend(f"<li>{inline_html(item)}</li>" for item in block["items"])
            out.append(f"</{tag}>")
        elif kind == "table":
            out.append("<table><thead><tr>")
            out.extend(f"<th>{inline_html(c)}</th>" for c in block["header"])
            out.append("</tr></thead><tbody>")
            for row in block["rows"]:
                out.append("<tr>")
                out.extend(f"<td>{inline_html(c)}</td>" for c in row)
                out.append("</tr>")
            out.append("</tbody></table>")
        elif kind == "quote":
            out.append(f"<blockquote><p>{inline_html(block['text'])}</p></blockquote>")
        elif kind == "rule":
            out.append("<hr>")
    return "\n".join(out)


def build_page(title: str, body: str) -> str:
    return (
        "<!doctype html>\n"
        '<html lang="es">\n'
        "<head>\n"
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{html.escape(title)}</title>\n"
        f"<style>\n{STYLE}\n</style>\n"
        "</head>\n<body>\n<main>\n"
        f"{body}\n"
        "</main>\n</body>\n</html>\n"
    )


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)

    for name, page_title in DOCUMENTS.items():
        source = OUT / f"{name}.md"
        if not source.exists():
            raise SystemExit(f"Missing {source.name}")

        markdown = source.read_text(encoding="utf-8")
        blocks = parse(markdown)
        body = render_html(blocks)

        # A parsing bug would show up as Markdown syntax surviving into the
        # HTML. Fail loudly instead of publishing a broken page.
        leftovers = re.findall(r"\*\*|^#{1,6} |^\| ", body, flags=re.MULTILINE)
        if leftovers:
            raise SystemExit(f"{source.name}: unconverted Markdown in the output")

        (OUT / f"{name}.html").write_text(
            build_page(page_title, body), encoding="utf-8"
        )

        title = next(
            (b["text"] for b in blocks if b["type"] == "heading" and b["level"] == 1),
            page_title,
        )
        # The date lives in the first paragraph, written as bold label plus
        # value. Strip the emphasis markers so the app can show it plainly.
        updated = ""
        for block in blocks:
            if block["type"] != "paragraph":
                continue
            plain = block["text"].replace("**", "")
            if plain.startswith("Última actualización:"):
                updated = plain.split(":", 1)[1].strip()
                break
        if not updated:
            raise SystemExit(f"{source.name}: no 'Última actualización' line found")
        (ASSETS / f"{name}.json").write_text(
            json.dumps(
                {
                    "id": name,
                    "title": title,
                    "updated": updated,
                    "blocks": blocks,
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"{name}: {len(blocks)} blocks -> .html and assets/legal/{name}.json")


if __name__ == "__main__":
    main()
