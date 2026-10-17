"""Adversarial test table for normalization + SimHash, plus the shared vectors file."""
import json
from pathlib import Path

import pytest

from backend.app.core.fingerprint import compute_fingerprint
from backend.app.core.normalize import normalize
from backend.app.core.simhash import hamming, prefix, simhash_hex

ROOT = Path(__file__).resolve().parents[2]

# (name, input, expected normalized output)
ADVERSARIAL = [
    ("plain_case_punctuation", "BREAKING NEWS: Hot Water Cures Dengue!!!", "breaking news hot water cures dengue"),
    ("cyrillic_homoglyphs", "H\u043et w\u0430ter cures d\u0435ngue", "hot water cures dengue"),
    ("greek_homoglyph", "d\u03b5ngue fever", "dengue fever"),
    ("zero_width_inside_word", "hot\u200bwater de\u200dngue", "hotwater dengue"),
    ("soft_hyphen", "dis\u00adease", "disease"),
    ("bom_and_bidi_marks", "\ufeffhot\u202e water", "hot water"),
    ("fullwidth", "\uff28\uff2f\uff34 \uff37\uff21\uff34\uff25\uff32", "hot water"),
    ("math_bold", "\U0001d421\U0001d428\U0001d42d \U0001d430\U0001d41a\U0001d42d\U0001d41e\U0001d42b", "hot water"),
    ("emoji_between_words", "hot \U0001f525 water \U0001f4a7 cures \U0001f637 dengue", "hot water cures dengue"),
    ("emoji_variation_selector", "hot\u2764\ufe0f water", "hot water"),
    ("repeated_letters", "cooool nahiiiii", "cool nahi"),
    ("digits_not_squeezed", "1000000 rupees", "1000000 rupees"),
    ("whitespace_variants", "hot\twater\n\ncures   dengue\u00a0fever", "hot water cures dengue fever"),
    ("apostrophe_hyphen", "don't-panic", "don t panic"),
    ("roman_urdu_variants", "Nhi bohat zyada bukhaar", "nahi bahut zyada bukhar"),
    ("roman_urdu_spelling_pair_a", "ye jhoot hai", "yeh jhoot hai"),
    ("roman_urdu_spelling_pair_b", "yah jhut hay", "yeh jhoot hai"),
    ("arabic_digits", "\u0662\u0660\u0662\u0666", "2026"),
    ("persian_digits", "\u06f1\u06f2\u06f3", "123"),
    ("arabic_kaf_yeh", "\u0643\u062a\u0627\u0628 \u0627\u064a\u0643", "\u06a9\u062a\u0627\u0628 \u0627\u06cc\u06a9"),
    ("urdu_diacritics_removed", "\u067e\u064e\u0627\u0646\u06cc", "\u067e\u0627\u0646\u06cc"),
    ("empty", "", ""),
    ("only_symbols", "!!! \U0001f525 ???", ""),
]


@pytest.mark.parametrize("name,text,expected", ADVERSARIAL, ids=[c[0] for c in ADVERSARIAL])
def test_normalize_table(name, text, expected):
    assert normalize(text) == expected


def test_normalize_is_idempotent():
    for _, text, _ in ADVERSARIAL:
        once = normalize(text)
        assert normalize(once) == once


BASE = "Drinking hot water cures dengue fever according to doctors"


def test_obfuscated_variants_share_one_fingerprint():
    variants = [
        BASE.upper(),
        "Drinking h\u043et w\u0430ter cures d\u0435ngue fever according to doctors",
        "Drin\u200bking hot \U0001f525 water cures dengue fever, according to doctors!!!",
        "\uff24rinking hot water cures dengue fever according to doctors",
    ]
    ref = compute_fingerprint(BASE)
    assert all(compute_fingerprint(v) == ref for v in variants)


def test_similar_closer_than_unrelated():
    base = compute_fingerprint(BASE)
    similar = compute_fingerprint("Drinking hot water cures dengue fever according to some doctors")
    unrelated = compute_fingerprint("The government announced a new budget for schools today")
    assert hamming(base, similar) < hamming(base, unrelated)


def test_fingerprint_shape():
    fp = simhash_hex(normalize(BASE))
    assert len(fp) == 16 and fp == fp.lower() and int(fp, 16) >= 0
    assert prefix(fp) == fp[:4]
    assert simhash_hex("") == "0" * 16


def test_short_inputs_use_single_shingle():
    assert simhash_hex("hello") != simhash_hex("hello world")


def test_shared_vectors_file():
    vectors = json.loads((ROOT / "shared" / "fingerprint_vectors.json").read_text(encoding="utf-8"))
    assert len(vectors["vectors"]) >= 15
    for v in vectors["vectors"]:
        assert normalize(v["input"]) == v["normalized"], v["name"]
        assert compute_fingerprint(v["input"]) == v["fingerprint"], v["name"]
