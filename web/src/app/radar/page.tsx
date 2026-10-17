"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { getRadar } from "@/lib/api";
import { RadarItem } from "@/lib/types";
import { glass, pageBg } from "@/lib/ui";

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
        <header className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Rumor Radar</h1>
          <Link href="/" className="text-sm text-indigo-300 hover:underline">← Check a message</Link>
        </header>
        <p className="text-sm text-white/60">
        Claims reported by at least 10 different installs on at least 3 different networks.
        </p>

        {error && <div className={`${glass} text-rose-300`}>{error}</div>}
        {!items && !error && <div className={glass}>Loading...</div>}
        {items?.length === 0 && <div className={glass}>No trending rumors right now.</div>}

        {items?.map((it) => (
          <div key={it.fingerprint} className={`${glass} flex items-start justify-between gap-4`}>
            <div>
              <div className="font-medium">{it.claim}</div>
              <div className="mt-1 text-xs text-white/50">
                {fmt(it.first_seen)} to {fmt(it.last_seen)}
              </div>
            </div>
            <div className="shrink-0 text-center">
              <div className="text-2xl font-bold text-indigo-300">{it.reports}</div>
              <div className="text-xs text-white/50">reports</div>
            </div>
          </div>
        ))}
      </div>
    </main>
  );
}
