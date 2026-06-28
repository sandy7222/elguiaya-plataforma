#!/usr/bin/env python3
"""Migra ElevatedButton.icon / OutlinedButton.icon / TextButton.icon a Safe*IconButton."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

BUTTON_MAP = {
    "ElevatedButton.icon": "SafeElevatedIconButton",
    "OutlinedButton.icon": "SafeOutlinedIconButton",
    "TextButton.icon": "SafeTextIconButton",
    "FilledButton.icon": "SafeFilledIconButton",
}

SKIP_ICON_HINTS = (
    "_isRunning",
    "_isLoading",
    "_procesando",
    "_guardando",
    "_isLoadingDireccion",
    "_isProcesando",
    "_isSaving",
    "_isEnviando",
    "isUploading",
    "enviando",
    "CircularProgressIndicator",
    "SizedBox(",
)


def import_line(dart_file: Path) -> str:
    rel = dart_file.relative_to(LIB)
    parts = rel.parts
    if parts[0] == "widgets":
        return "import 'safe_button.dart';"
    ups = "../" * (len(parts) - 1)
    return f"import '{ups}widgets/safe_button.dart';"


def add_import(content: str, dart_file: Path) -> str:
    line = import_line(dart_file)
    if line in content or "safe_button.dart" in content:
        return content
    m = re.search(r"^(import .+?;\n)+", content, re.MULTILINE)
    if m:
        return content[: m.end()] + line + "\n" + content[m.end() :]
    return line + "\n" + content


def balanced_extract(s: str, start: int) -> tuple[str, int] | None:
    """Extrae desde start (primer '(') hasta el ')' balanceado."""
    if start >= len(s) or s[start] != "(":
        return None
    depth = 0
    i = start
    while i < len(s):
        if s[i] == "(":
            depth += 1
        elif s[i] == ")":
            depth -= 1
            if depth == 0:
                return s[start : i + 1], i + 1
        i += 1
    return None


def parse_icon(icon_src: str) -> tuple[str, dict[str, str]] | None:
    icon_src = icon_src.strip()
    if any(h in icon_src for h in SKIP_ICON_HINTS):
        return None

    if not icon_src.startswith("Icon(") and not icon_src.startswith("const Icon("):
        return None

    inner_start = icon_src.index("(")
    extracted = balanced_extract(icon_src, inner_start)
    if not extracted:
        return None
    block, _ = extracted
    inner = block[1:-1]

    icon_m = re.search(r"(Icons\.[\w_]+)", inner)
    if not icon_m:
        return None
    extra: dict[str, str] = {}
    size_m = re.search(r"size:\s*([\d.]+)", inner)
    color_m = re.search(r"color:\s*([^,\n)]+)", inner)
    if size_m:
        extra["iconSize"] = size_m.group(1).strip()
    if color_m:
        extra["iconColor"] = color_m.group(1).strip()
    return icon_m.group(1), extra


def parse_text_widget(label_src: str) -> dict | None:
    label_src = label_src.strip()
    if any(h in label_src for h in SKIP_ICON_HINTS):
        return None
    if "?" in label_src and ":" in label_src:
        return None

    for prefix in ("const Text(", "Text("):
        if not label_src.startswith(prefix):
            continue
        extracted = balanced_extract(label_src, label_src.index("("))
        if not extracted:
            continue
        block, _ = extracted
        inner = block[1:-1].strip()

        str_m = re.match(r"'((?:\\'|[^'])*)'", inner)
        if str_m:
            text = str_m.group(1).replace("\\'", "'")
            rest = inner[str_m.end() :].strip()
            out: dict = {"text": text}
            if rest.startswith(","):
                rest = rest[1:].strip()
                if rest.startswith("style:"):
                    style_val = rest[len("style:") :].strip()
                    out["textStyle"] = style_val
            return out

        str_m = re.match(r'"((?:\\"|[^"])*)"', inner)
        if str_m:
            text = str_m.group(1).replace('\\"', '"')
            rest = inner[str_m.end() :].strip()
            out = {"text": text}
            if rest.startswith(","):
                rest = rest[1:].strip()
                if rest.startswith("style:"):
                    out["textStyle"] = rest[len("style:") :].strip()
            return out

        var_m = re.match(r"(\w+)\s*,\s*style:\s*", inner)
        if var_m:
            style_start = inner.index("style:") + len("style:")
            style_val = inner[style_start:].strip()
            return {"expr": var_m.group(1), "textStyle": style_val}

        var_only = re.match(r"(\w+)\s*$", inner)
        if var_only:
            return {"expr": var_only.group(1)}
    return None


def split_named_params(inner: str) -> dict[str, str]:
    params: dict[str, str] = {}
    i = 0
    n = len(inner)
    while i < n:
        while i < n and inner[i] in " \n\t,":
            i += 1
        if i >= n:
            break
        name_m = re.match(r"(\w+):", inner[i:])
        if not name_m:
            break
        name = name_m.group(1)
        i += name_m.end()
        depth = 0
        start = i
        while i < n:
            c = inner[i]
            if c == "(":
                depth += 1
            elif c == ")":
                if depth == 0:
                    break
                depth -= 1
            elif c == "," and depth == 0:
                break
            i += 1
        params[name] = inner[start:i].strip()
        i += 1
    return params


def find_blocks(content: str) -> list[tuple[int, int, str]]:
    pattern = re.compile(r"(ElevatedButton|OutlinedButton|TextButton|FilledButton)\.icon\(")
    blocks: list[tuple[int, int, str]] = []
    for m in pattern.finditer(content):
        paren = m.end() - 1
        extracted = balanced_extract(content, paren)
        if extracted:
            _, end = extracted
            blocks.append((m.start(), end, m.group(1)))
    return blocks


def convert_block(full: str, btn_type: str) -> str | None:
    inner = full[full.index("(") + 1 : full.rindex(")")]
    params = split_named_params(inner)
    if "icon" not in params or "label" not in params:
        return None

    icon_parsed = parse_icon(params["icon"])
    label_parsed = parse_text_widget(params["label"])
    if not icon_parsed or not label_parsed:
        return None

    icon_data, icon_extra = icon_parsed
    safe_type = BUTTON_MAP[f"{btn_type}.icon"]

    lines = [f"{safe_type}("]
    if "onPressed" in params:
        lines.append(f"  onPressed: {params['onPressed']},")
    lines.append(f"  icon: {icon_data},")
    for k, v in icon_extra.items():
        lines.append(f"  {k}: {v},")
    if "text" in label_parsed:
        lines.append(f"  label: {repr(label_parsed['text'])},")
    elif "expr" in label_parsed:
        lines.append(f"  label: {label_parsed['expr']},")
    if "textStyle" in label_parsed:
        lines.append(f"  textStyle: {label_parsed['textStyle']},")
    if "style" in params:
        lines.append(f"  style: {params['style']},")
    lines.append(")")
    return "\n".join(lines)


def migrate_content(content: str, dart_file: Path) -> tuple[str, int]:
    if dart_file.name == "safe_button.dart":
        return content, 0
    if not re.search(r"Button\.icon\(", content):
        return content, 0

    converted = 0
    while True:
        blocks = find_blocks(content)
        if not blocks:
            break
        changed = False
        for start, end, btn_type in reversed(blocks):
            block = content[start:end]
            new_block = convert_block(block, btn_type)
            if new_block:
                content = content[:start] + new_block + content[end:]
                converted += 1
                changed = True
                break
        if not changed:
            break

    if converted:
        content = add_import(content, dart_file)
    return content, converted


def main() -> int:
    total = 0
    files_changed: list[str] = []
    for path in sorted(LIB.rglob("*.dart")):
        if path.name == "safe_button.dart":
            continue
        text = path.read_text(encoding="utf-8")
        new_text, n = migrate_content(text, path)
        if n:
            path.write_text(new_text, encoding="utf-8")
            files_changed.append(f"{path.relative_to(ROOT)} ({n})")
            total += n

    print(f"Converted {total} buttons in {len(files_changed)} files")
    for f in files_changed:
        print(f"  - {f}")

    remaining = sum(
        len(re.findall(r"Button\.icon\(", path.read_text(encoding="utf-8")))
        for path in LIB.rglob("*.dart")
        if path.name != "safe_button.dart"
    )
    print(f"Remaining Button.icon: {remaining}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
