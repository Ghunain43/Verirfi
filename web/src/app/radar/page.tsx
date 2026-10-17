import Link from "next/link";
import { glass, pageBg } from "@/lib/ui";

export default function RadarPage() {
  return (
    <main className={pageBg}>
      <div className="mx-auto max-w-2xl space-y-4">
        <header className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Rumor Radar</h1>
          <Link href="/" className="text-sm text-indigo-300 hover:underline">← Check a message</Link>
        </header>
        <div className={`${glass} space-y-2`}>
          <h2 className="text-lg font-semibold">Not available yet</h2>
          <p className="text-sm text-white/70">
            The current backend does not provide rumor reporting or a radar endpoint.
            This page will be enabled when those backend features are implemented.
          </p>
        </div>
      </div>
    </main>
  );
}
