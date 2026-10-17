"use client";
import { useEffect, useState } from "react";
import { getRadar } from "@/lib/api";
import { RadarItem } from "@/lib/types";
import { glass, pageBg } from "@/lib/ui";

const safeUrl = (u?: string | null) => (u && /^https?:\/\//i.test(u) ? u : undefined);
const fmt = (s: string) => new Date(s).toLocaleDateString("en-GB", { day: "numeric", month: "short" });

export default function Radar() {
  const [items, setItems] = useState<RadarItem[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    getRadar().then(setItems).catch(() => setError("Couldn't load the radar. Please try again later."));
  }, []);

  return (
    <main className={pageBg}>
      <div className="mx-auto max-w-2xl space-y-4">
        <header className="pt-4">
          <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">Rumor <span className="grad-text">Radar</span></h1>
          <p className="mt-2 text-sm text-white/55">
            False claims spreading right now. A claim appears when at least 10 people on 3 different networks checked it. If fewer qualify, claims rated false by fact-checkers fill the list.
          </p>
        </header>

        {error && <div className={`${glass} text-rose-300`}>{error}</div>}
        {!items && !error && [0, 1, 2].map((i) => <div key={i} className="shimmer h-28 rounded-3xl" />)}
        {items?.length === 0 && <div className={glass}>No trending rumors right now.</div>}

        {items?.map((it, idx) => {
          const web = it.origin === "web";
          const href = safeUrl(it.source_url);
          const why = it.why || (web ? "Fact-checkers rated this claim false." : `Checked by ${it.reports} different people on several networks, so it is spreading.`);
          return (
            <div key={it.fingerprint} className={`${glass} flex gap-4`}>
              <div className="grad-text w-7 shrink-0 text-xl font-bold">{idx + 1}</div>
              <div className="min-w-0 flex-1">
                <span className={`mb-2 inline-block rounded-full px-2.5 py-0.5 text-xs ${web ? "bg-rose-400/15 text-rose-300" : "bg-indigo-400/15 text-indigo-300"}`}>
                  {web ? "Rated false by fact-checkers" : "Spreading in the community"}
                </span>
                <div className="text-lg font-medium leading-snug">{it.claim}</div>
                <div className="mt-3 rounded-xl border border-white/10 bg-white/5 p-3 text-sm text-white/70">
                  <span className="text-[11px] font-medium uppercase tracking-[0.14em] text-white/45">Why it&apos;s here</span>
                  <p className="mt-1">{why}</p>
                </div>
                <div className="mt-2 text-xs text-white/45">
                  {web
                    ? href
                      ? <a href={href} target="_blank" rel="noopener noreferrer" className="text-indigo-300 hover:underline">Source: {it.publisher || "fact-check"} ↗</a>
                      : <>Source: {it.publisher || "fact-check"}</>
                    : <>{fmt(it.first_seen)} to {fmt(it.last_seen)}</>}
                </div>
              </div>
              {!web && (
                <div className="shrink-0 text-center">
                  <div className="text-3xl font-bold text-indigo-300">{it.reports}</div>
                  <div className="text-xs text-white/45">checks</div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </main>
  );
}
