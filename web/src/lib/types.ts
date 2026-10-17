export type Stance = "supporting" | "contradicting" | "neutral";
export type ReasonUnchecked =
  | "opinion" | "satire" | "religious" | "prediction" | "too_vague" | "no_claim";

export type Evidence = {
  title: string;
  url: string;
  publisher: string | null;
  stance: Stance;
  quality: number; // 0..1
  snippet: string | null;
};

export type QuickCheckResult = {
  checkable: boolean;
  claim: string;
  reason_unchecked: ReasonUnchecked | null;
  likely_answer: string | null;
  confidence_low: number;
  confidence_high: number;
  evidence: Evidence[];
  lang_detected: string;
  fingerprint: string;
  cached: boolean;
  took_ms: number;
};

export type RadarItem = {
  fingerprint: string;
  claim: string;
  reports: number; // distinct installs; 0 for web-found claims
  first_seen: string;
  last_seen: string;
  origin?: "community" | "web"; // web = rated false by fact-checkers, found by search
  source_url?: string | null;
  publisher?: string | null;
  why?: string | null; // short reason this claim is listed
};
