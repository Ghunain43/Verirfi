import { QuickCheckResult, Stance } from "@/lib/types";
import { glass } from "@/lib/ui";

// Why a text was not judged, and what to do about it.
const REASON: Record<string, { title: string; why: string }> = {
  opinion: { title: "Opinion", why: "This says how someone feels or what they prefer. There is no fact to verify, so we don't rate it. If it hides a factual claim (a number, an event, a statement about the world), paste just that part." },
  satire: { title: "Satire or joke", why: "This reads like humor or satire. It isn't meant to be taken literally, so we don't rate it as true or false." },
  religious: { title: "Matter of faith", why: "This is a belief or religious teaching. Facts can't confirm or refute it, so we stay out of it." },
  prediction: { title: "Prediction", why: "This describes something that hasn't happened yet. It can only be checked after the fact. Check back when the date has passed." },
  too_vague: { title: "Too vague", why: "There is no specific person, place, number or event to search for. Add who, what and when, then check again." },
  no_claim: { title: "No checkable claim", why: "We couldn't find a statement about the world in this text. Try pasting the sentence that makes the claim." },
};

const STANCE: Record<Stance, { label: string; cls: string }> = {
  supporting: { label: "Supports", cls: "text-emerald-300" },
  contradicting: { label: "Contradicts", cls: "text-rose-300" },
  neutral: { label: "Neutral", cls: "text-slate-300" },
};

const label = "text-[11px] font-medium uppercase tracking-[0.14em] text-white/45";

function tone(answer: string) {
  const a = answer.toLowerCase();
  if (/false|misleading|contradict/.test(a)) return { chip: "Likely false", cls: "bg-rose-400/15 text-rose-300", bar: "from-rose-400 to-fuchsia-400" };
  if (/true|support|accurate/.test(a)) return { chip: "Likely true", cls: "bg-emerald-400/15 text-emerald-300", bar: "from-emerald-300 to-cyan-300" };
  return { chip: "Unclear", cls: "bg-amber-400/15 text-amber-300", bar: "from-amber-300 to-orange-400" };
}

export default function ResultCard({ r }: { r: QuickCheckResult }) {
  if (!r.checkable) {
    const info = (r.reason_unchecked && REASON[r.reason_unchecked]) || REASON.no_claim;
    return (
      <div className={`${glass} space-y-3`}>
        <span className="inline-block rounded-full bg-sky-400/15 px-3 py-1 text-xs font-medium text-sky-300">Not rated · {info.title}</span>
        <div className="text-xl font-semibold">We don&apos;t judge this kind of statement.</div>
        <div>
          <div className={label}>Why</div>
          <p className="mt-1 text-white/75">{info.why}</p>
        </div>
        <div className="text-xs text-white/40">Text we read: {r.claim}</div>
      </div>
    );
  }

  const low = Math.round(r.confidence_low * 100);
  const high = Math.round(r.confidence_high * 100);
  const answer = r.likely_answer?.trim() || "Not enough evidence to say";
  const t = tone(answer);
  const n = (s: Stance) => r.evidence.filter((e) => e.stance === s).length;

  return (
    <div className={`${glass} space-y-6`}>
      <div className="flex flex-wrap items-center gap-3">
        <span className={`rounded-full px-3 py-1 text-xs font-semibold ${t.cls}`}>{t.chip}</span>
        <span className="text-xs text-white/40">{r.cached ? "From cache" : "Fresh check"} · {(r.took_ms / 1000).toFixed(1)}s</span>
      </div>
      <div>
        <div className={label}>Claim</div>
        <div className="mt-1 text-white/85">{r.claim}</div>
      </div>
      <div>
        <div className={label}>Likely answer</div>
        <div className="mt-1 text-2xl font-semibold leading-snug">{answer}</div>
      </div>
      <div>
        <div className="mb-2 flex justify-between text-xs text-white/55"><span>Confidence range</span><span>{low}% to {high}%</span></div>
        <div className="relative h-2.5 rounded-full bg-white/10">
          <div className={`absolute h-2.5 rounded-full bg-gradient-to-r ${t.bar}`} style={{ left: `${low}%`, width: `${Math.max(high - low, 1)}%` }} />
        </div>
      </div>
      <div className="space-y-3">
        <div className={label}>Why · {r.evidence.length} source{r.evidence.length === 1 ? "" : "s"}
          {r.evidence.length > 0 && ` (${n("contradicting")} contradict, ${n("supporting")} support, ${n("neutral")} neutral)`}</div>
        {r.evidence.length === 0 && <div className="text-white/60">No evidence found.</div>}
        {r.evidence.map((e, i) => (
          <a key={i} href={e.url} target="_blank" rel="noopener noreferrer"
            className="block rounded-2xl border border-white/10 bg-white/5 p-4 transition hover:bg-white/10">
            <div className="font-medium">{e.title}</div>
            <div className="mt-1 flex flex-wrap gap-x-3 text-xs text-white/55">
              <span>{e.publisher ?? "Unknown"}</span>
              <span className={STANCE[e.stance].cls}>{STANCE[e.stance].label}</span>
              <span>Quality {Math.round(e.quality * 100)}%</span>
            </div>
            {e.snippet && <div className="mt-2 text-sm text-white/75">{e.snippet}</div>}
          </a>
        ))}
      </div>
    </div>
  );
}
