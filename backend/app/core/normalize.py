"""Text normalization for fingerprinting (API.md section 4).

Pipeline (the TypeScript and Dart ports must do exactly this):
 1. Unicode NFKC, then lowercase
 2. delete invisible chars: category Cf (zero-width, soft hyphen, bidi marks...),
    variation selectors U+FE00-FE0F, combining grapheme joiner U+034F
 3. apply char_map from shared/normalize_map.json (homoglyphs, Arabic digits, Urdu letter forms,
    deletes Arabic diacritics)
 4. every char that is not a letter (L*), digit (N*) or combining mark (Mn, Mc) becomes a space.
    This also removes punctuation, symbols and emoji
 5. split on spaces; per token: squeeze runs of 3+ identical letters down to 2,
    then map Roman Urdu variants to the canonical spelling
 6. join with a single space
"""
import json
import unicodedata
from pathlib import Path

_MAP_PATH = Path(__file__).resolve().parents[3] / "shared" / "normalize_map.json"

with open(_MAP_PATH, encoding="utf-8") as _f:
    _MAP = json.load(_f)

CHAR_MAP: dict[str, str] = _MAP["char_map"]
ROMAN_URDU: dict[str, str] = _MAP["roman_urdu"]


def _invisible(ch: str) -> bool:
    cp = ord(ch)
    return unicodedata.category(ch) == "Cf" or 0xFE00 <= cp <= 0xFE0F or cp == 0x034F


def _keep(ch: str) -> bool:
    cat = unicodedata.category(ch)
    return cat[0] in "LN" or cat in ("Mn", "Mc")


def squeeze(token: str) -> str:
    """Runs of 3+ identical letters become 2 ('nahiiii' -> 'nahii'). Digits are never squeezed."""
    out = []
    prev, run = None, 0
    for ch in token:
        if ch == prev:
            run += 1
        else:
            prev, run = ch, 1
        if run > 2 and unicodedata.category(ch)[0] == "L":
            continue
        out.append(ch)
    return "".join(out)


def normalize(text: str) -> str:
    t = unicodedata.normalize("NFKC", text).lower()
    t = "".join(ch for ch in t if not _invisible(ch))
    t = "".join(CHAR_MAP.get(ch, ch) for ch in t)
    t = "".join(ch if _keep(ch) else " " for ch in t)
    tokens = []
    for tok in t.split():
        tok = squeeze(tok)
        tokens.append(ROMAN_URDU.get(tok, tok))
    return " ".join(tokens)
