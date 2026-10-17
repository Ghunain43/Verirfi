"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { getRadar } from "@/lib/api";
import { RadarItem } from "@/lib/types";
import { glass, pageBg } from "@/lib/ui";

export default function Admin() {
  const [items, setItems] = useState<RadarItem[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    getRadar()
      .then((d) => setItems([...d].sort((a, b) => b.reports - a.reports)))
      .catch(() => setError("Couldn't load data."));
  }, []);

  const total = items?.reduce((n, i) => n + i.reports, 0) ?? 0;

  return (
    <main className={pageBg}>
      <div className="mx-auto max-w-3xl space-y-4">
        <header className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Admin</h1>
          <Link href="/" className="text-sm text-indigo-300 hover:underline">← Home</Link>
        </header>

        {error && <div className={`${glass} text-rose-300`}>{error}</div>}

        <div className="grid grid-cols-2 gap-4">
          <div className={glass}><div className="text-3xl font-bold">{items?.length ?? "-"}</div><div className="text-xs text-white/50">Trending claims</div></div>
          <div className={glass}><div className="text-3xl font-bold">{items ? total : "-"}</div><div className="text-xs text-white/50">Total reports</div></div>
        </div>

        <div className={`${glass} overflow-x-auto`}>
          <table className="w-full text-left text-sm">
            <thead className="text-white/50">
              <tr><th className="pb-2">Claim</th><th className="pb-2">Reports</th><th className="pb-2">First seen</th><th className="pb-2">Last seen</th></tr>
            </thead>
            <tbody>
              {items?.map((i) => (
                <tr key={i.fingerprint} className="border-t border-white/10">
                  <td className="py-2 pr-3">{i.claim}</td>
                  <td className="py-2 pr-3 font-semibold text-indigo-300">{i.reports}</td>
                  <td className="py-2 pr-3 text-white/60">{new Date(i.first_seen).toLocaleDateString("en-GB")}</td>
                  <td className="py-2 text-white/60">{new Date(i.last_seen).toLocaleDateString("en-GB")}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </main>
  );
}
