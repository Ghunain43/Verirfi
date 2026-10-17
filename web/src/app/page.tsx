"use client";
import { useState } from "react";
import { quickCheck, ApiError } from "@/lib/api";
import { QuickCheckResult } from "@/lib/types";
import { glass, pageBg } from "@/lib/ui";
import ResultCard from "@/components/ResultCard";

const MAX = 2000;

function errorMessage(e: unknown): string {
  if (!(e instanceof ApiError)) return "Couldn't reach the server. Check your connection and try again.";
  switch (e.code) {
    case "invalid_input":
      return "That text isn't valid. Empty text or text over 2000 characters can't be checked.";
    case "invalid_token":
      return "Your session expired. Press Check again and we'll get a new token.";
    case "rate_limited": {
      const mins = e.retryAfter ? Math.ceil(e.retryAfter / 60) : null;
      return `You've reached the limit of 20 checks per hour.${
        mins ? ` Try again in about ${mins} minute${mins > 1 ? "s" : ""}.` : " Please try again later."
      }`;
    }
    case "upstream_failed":
      return "The research service isn't responding right now. Please try again shortly.";
    case "timeout":
      return "The check took too long. Please try again.";
    default:
      return "Something went wrong. Please try again.";
  }
}

export default function Home() {
  const [text, setText] = useState("");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<QuickCheckResult | null>(null);
  const [error, setError] = useState("");

  async function onCheck() {
    setLoading(true);
    setError("");
    setResult(null);
    try {
      setResult(await quickCheck(text.trim()));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className={pageBg}>
      <div className="mx-auto max-w-2xl space-y-4">
        <header className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Verifi</h1>
          <span className="text-sm text-white/50">Backend-powered claim checks</span>
        </header>

        <div className={glass}>
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            maxLength={MAX}
            rows={6}
            placeholder="Paste the message you want to check..."
            className="w-full resize-none bg-transparent outline-none placeholder:text-white/30"
          />
          <div className="mt-2 flex items-center justify-between">
            <span className="text-xs text-white/40">{text.length}/{MAX}</span>
            <button
              onClick={onCheck}
              disabled={loading || !text.trim()}
              className="rounded-xl bg-indigo-500 px-5 py-2 font-medium disabled:opacity-40"
            >
              {loading ? "Checking..." : "Check"}
            </button>
          </div>
        </div>

        {error && <div className={`${glass} text-rose-300`}>{error}</div>}
        {result && <ResultCard r={result} />}

        <p className="pt-2 text-center text-xs text-white/30">
          Your message is never saved or logged.
        </p>
      </div>
    </main>
  );
}
