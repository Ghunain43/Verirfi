"use client";
import { useState } from "react";
import { quickCheck, ApiError } from "@/lib/api";
import { QuickCheckResult } from "@/lib/types";
import { glass, pageBg } from "@/lib/ui";
import ResultCard from "@/components/ResultCard";

const MAX = 2000;
const EXAMPLES = ["Drinking hot water cures dengue fever.", "Petrol will be unavailable from tomorrow.", "Free laptops are being given to all students."];

function errorMessage(e: unknown): string {
  if (!(e instanceof ApiError)) return "Couldn't reach the server. Check your connection and try again.";
  switch (e.code) {
    case "invalid_input": return "That text isn't valid. Empty text or text over 2000 characters can't be checked.";
    case "invalid_token": return "Your session expired. Press Check again and we'll get a new token.";
    case "rate_limited": {
      const mins = e.retryAfter ? Math.ceil(e.retryAfter / 60) : null;
      return `You've reached the limit of 20 checks per hour.${mins ? ` Try again in about ${mins} minute${mins > 1 ? "s" : ""}.` : " Please try again later."}`;
    }
    case "upstream_failed": return "The research service isn't responding right now. Please try again shortly.";
    case "timeout": return "The check took too long. Please try again.";
    default: return "Something went wrong. Please try again.";
  }
}

export default function Check() {
  const [text, setText] = useState("");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<QuickCheckResult | null>(null);
  const [error, setError] = useState("");

  async function onCheck() {
    setLoading(true); setError(""); setResult(null);
    try { setResult(await quickCheck(text.trim())); }
    catch (e) { setError(errorMessage(e)); }
    finally { setLoading(false); }
  }

  return (
    <main className={pageBg}>
      <div className="mx-auto max-w-2xl space-y-5">
        <header className="pt-4">
          <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">Check a <span className="grad-text">claim</span></h1>
          <p className="mt-2 text-sm text-white/55">Paste a message, headline or forward. We find the claim and weigh it against sources.</p>
        </header>

        <div className={glass}>
          <textarea value={text} onChange={(e) => setText(e.target.value)} maxLength={MAX} rows={6}
            placeholder="Paste the message you want to check..."
            className="w-full resize-none bg-transparent text-base outline-none placeholder:text-white/30" />
          <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
            <div className="flex flex-wrap gap-2">
              {!text && EXAMPLES.map((ex) => (
                <button key={ex} onClick={() => setText(ex)} className="btn-ghost rounded-full px-3 py-1 text-xs text-white/60">{ex}</button>
              ))}
              {text && <span className="text-xs text-white/40">{text.length}/{MAX}</span>}
            </div>
            <button onClick={onCheck} disabled={loading || !text.trim()} className="btn-primary rounded-xl px-6 py-2.5 font-semibold disabled:opacity-40">
              {loading ? "Checking..." : "Check"}
            </button>
          </div>
        </div>

        {loading && (
          <div className={`${glass} space-y-3`}>
            <div className="shimmer h-4 w-1/3 rounded" /><div className="shimmer h-7 w-4/5 rounded" /><div className="shimmer h-3 w-full rounded-full" />
            <p className="text-xs text-white/40">Searching sources. This usually takes a few seconds.</p>
          </div>
        )}
        {error && <div className={`${glass} text-rose-300`}>{error}</div>}
        {result && <ResultCard r={result} />}
        <p className="pt-2 text-center text-xs text-white/30">Your message is never saved or logged.</p>
      </div>
    </main>
  );
}
