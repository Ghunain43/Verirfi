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

export type LookupEntry = {
  fingerprint: string;
  claim: string;
  likely_answer: string | null;
  confidence_low: number;
  confidence_high: number;
  evidence: Evidence[];
  checked_at: string;
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
