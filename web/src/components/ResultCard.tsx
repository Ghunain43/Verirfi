import { QuickCheckResult, Stance } from "@/lib/types";
import { glass } from "@/lib/ui";

const REASON: Record<string, string> = {
  opinion: "This is a personal opinion.",
  satire: "This looks like satire or a joke.",
  religious: "This is a matter of faith or religion.",
  prediction: "This is a prediction, so it can't be checked yet.",
  too_vague: "This is too vague to check.",
  no_claim: "We couldn't find a checkable claim in this text.",
};

const STANCE: Record<Stance, { label: string; cls: string }> = {
  supporting: { label: "Supports", cls: "text-emerald-300" },
  contradicting: { label: "Contradicts", cls: "text-rose-300" },
  neutral: { label: "Neutral", cls: "text-slate-300" },
};

export default function ResultCard({ r }: { r: QuickCheckResult }) {
  if (!r.checkable) {
    return (
      <div className={`${glass} space-y-2`}>
        <div className="text-lg font-semibold">
          This is an opinion, satire or belief. We don&apos;t judge those.
        </div>
        {r.reason_unchecked && <div className="text-white/70">{REASON[r.reason_unchecked]}</div>}
        <div className="text-xs text-white/50">Claim: {r.claim}</div>
      </div>
    );
  }

  const low = Math.round(r.confidence_low * 100);
  const high = Math.round(r.confidence_high * 100);
  const answer = r.likely_answer?.trim() || "Not enough evidence to say";

  return (
    <div className={`${glass} space-y-5`}>
      <div>
        <div className="text-xs uppercase tracking-wide text-white/50">Claim</div>
        <div>{r.claim}</div>
      </div>

      <div>
        <div className="text-xs uppercase tracking-wide text-white/50">Likely answer</div>
        <div className="text-xl font-semibold">{answer}</div>
      </div>

      <div>
        <div className="mb-1 flex justify-between text-xs text-white/60">
          <span>Confidence range</span>
          <span>{low}% to {high}%</span>
        </div>
        <div className="relative h-3 rounded-full bg-white/10">
          <div
            className="absolute h-3 rounded-full bg-indigo-400"
            style={{ left: `${low}%`, width: `${Math.max(high - low, 1)}%` }}
          />
        </div>
      </div>

      <div className="space-y-3">
        <div className="text-xs uppercase tracking-wide text-white/50">Evidence ({r.evidence.length})</div>
        {r.evidence.length === 0 && <div className="text-white/60">No evidence found.</div>}
        {r.evidence.map((e, i) => (
          <a
            key={i}
            href={e.url}
            target="_blank"
            rel="noopener noreferrer"
            className="block rounded-xl border border-white/10 bg-white/5 p-3 hover:bg-white/10"
          >
            <div className="font-medium">{e.title}</div>
            <div className="mt-0.5 flex flex-wrap gap-x-3 text-xs text-white/60">
              <span>{e.publisher ?? "Unknown"}</span>
              <span className={STANCE[e.stance].cls}>{STANCE[e.stance].label}</span>
              <span>Quality: {Math.round(e.quality * 100)}%</span>
            </div>
            {e.snippet && <div className="mt-1 text-sm text-white/80">{e.snippet}</div>}
          </a>
        ))}
      </div>

      <div className="text-xs text-white/40">
        {r.cached ? "From cache" : "Fresh check"} · {(r.took_ms / 1000).toFixed(1)}s
      </div>
    </div>
  );
}
