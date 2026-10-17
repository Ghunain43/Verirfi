"use client";
import { useState } from "react";
import Link from "next/link";
import { submitFactcheck } from "@/lib/factcheck";
import { ApiError } from "@/lib/api";
import { glass, pageBg } from "@/lib/ui";

const input = "w-full rounded-xl border border-white/10 bg-white/5 p-3 outline-none placeholder:text-white/30";

export default function FactCheckerPage() {
  const [apiKey, setApiKey] = useState(""); // kept in memory only, never in localStorage
  const [fingerprint, setFingerprint] = useState("");
  const [verdict, setVerdict] = useState("");
  const [explanation, setExplanation] = useState("");
  const [sourceUrl, setSourceUrl] = useState("");
  const [status, setStatus] = useState<"idle" | "sending" | "done" | "error">("idle");
  const [errMsg, setErrMsg] = useState("");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus("sending");
    try {
      await submitFactcheck(apiKey, { fingerprint, verdict, explanation, source_url: sourceUrl });
      setStatus("done");
    } catch (err) {
      const code = err instanceof ApiError ? err.status : 0;
      setErrMsg(
  code === 401 || code === 403
    ? "The API key was not accepted."
    : code === 429
    ? "Too many failed attempts. Please wait before trying again."
    : code === 400
    ? "Some fields are not valid. Check the fingerprint and link."
    : "Couldn't send. Please try again."
);
      setStatus("error");
    }
  }

  return (
    <main className={pageBg}>
      <div className="mx-auto max-w-2xl space-y-4">
        <header className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Fact-checker</h1>
          <Link href="/" className="text-sm text-indigo-300 hover:underline">← Home</Link>
        </header>

        <form onSubmit={onSubmit} className={`${glass} space-y-3`}>
          <input type="password" className={input} placeholder="Fact-checker API key"
            value={apiKey} onChange={(e) => setApiKey(e.target.value)} required />
          <input className={input} placeholder="Claim fingerprint (hex)"
            value={fingerprint} onChange={(e) => setFingerprint(e.target.value)} required />
          <input className={input} placeholder="Verdict (e.g. False, True, Partly true)"
            value={verdict} onChange={(e) => setVerdict(e.target.value)} required />
          <textarea rows={4} className={input} placeholder="Explanation"
            value={explanation} onChange={(e) => setExplanation(e.target.value)} required />
          <input type="url" className={input} placeholder="Source link (https://...)"
            value={sourceUrl} onChange={(e) => setSourceUrl(e.target.value)} required />
          <button disabled={status === "sending"}
            className="rounded-xl bg-indigo-500 px-5 py-2 font-medium disabled:opacity-40">
            {status === "sending" ? "Sending..." : "Publish response"}
          </button>
          {status === "done" && <p className="text-emerald-300">Response sent.</p>}
          {status === "error" && <p className="text-rose-300">{errMsg}</p>}
        </form>
      </div>
    </main>
  );
}
