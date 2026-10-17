"""Fixed sample responses from API.md section 9."""
OPINION_WORDS = ("worst", "best", "hate", "love", "terrible", "amazing", "should")

CHECKABLE = {
    "checkable": True,
    "claim": "Drinking hot water cures dengue fever.",
    "reason_unchecked": None,
    "likely_answer": "Most likely false: health authorities say there is no cure, only supportive care.",
    "confidence_low": 0.7,
    "confidence_high": 0.9,
    "evidence": [{
        "title": "Dengue fact sheet",
        "url": "https://www.who.int/news-room/fact-sheets/detail/dengue-and-severe-dengue",
        "publisher": "WHO",
        "stance": "contradicting",
        "quality": 0.95,
        "snippet": "No specific treatment exists; care is supportive.",
    }],
    "lang_detected": "en",
    "fingerprint": "a3f19c2b7d4e8a01",
    "cached": False,
    "took_ms": 120,
}

UNCHECKED = {
    "checkable": False,
    "claim": "This party is the worst thing to happen to our country.",
    "reason_unchecked": "opinion",
    "likely_answer": None,
    "confidence_low": 0.0,
    "confidence_high": 0.0,
    "evidence": [],
    "lang_detected": "en",
    "fingerprint": "5c01e9aa13b27f64",
    "cached": False,
    "took_ms": 80,
}


def mock_response(text: str) -> dict:
    """Opinion-sounding text gets the unchecked sample, everything else the checkable one."""
    if any(w in text.lower() for w in OPINION_WORDS):
        return dict(UNCHECKED)
    return dict(CHECKABLE)
