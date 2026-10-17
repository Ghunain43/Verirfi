import { QuickCheckResult } from "./types";

export const MOCK_CHECKABLE: QuickCheckResult = {
  checkable: true,
  claim: "Drinking hot water cures dengue fever.",
  reason_unchecked: null,
  likely_answer: "Most likely false: health authorities say there is no cure, only supportive care.",
  confidence_low: 0.7,
  confidence_high: 0.9,
  evidence: [
    {
      title: "Dengue fact sheet",
      url: "https://www.who.int/news-room/fact-sheets/detail/dengue-and-severe-dengue",
      publisher: "WHO",
      stance: "contradicting",
      quality: 0.95,
      snippet: "No specific treatment exists; care is supportive.",
    },
  ],
  lang_detected: "en",
  fingerprint: "a3f19c2b7d4e8a01",
  cached: false,
  took_ms: 120,
};

export const MOCK_UNCHECKED: QuickCheckResult = {
  checkable: false,
  claim: "This party is the worst thing to happen to our country.",
  reason_unchecked: "opinion",
  likely_answer: null,
  confidence_low: 0,
  confidence_high: 0,
  evidence: [],
  lang_detected: "en",
  fingerprint: "5c01e9aa13b27f64",
  cached: false,
  took_ms: 80,
};
