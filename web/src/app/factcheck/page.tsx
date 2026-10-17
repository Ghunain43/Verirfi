import Link from "next/link";
import { glass, pageBg } from "@/lib/ui";

export default function FactCheckerPage() {
  return (
    <main className={pageBg}>
      <div className="mx-auto max-w-2xl space-y-4">
        <header className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Fact-checker</h1>
          <Link href="/" className="text-sm text-indigo-300 hover:underline">← Home</Link>
        </header>
        <div className={`${glass} space-y-2`}>
          <h2 className="text-lg font-semibold">Publishing is not available yet</h2>
          <p className="text-sm text-white/70">
            The backend does not currently implement the fact-check publishing endpoint.
            No API key or submission is sent from this page.
          </p>
        </div>
      </div>
    </main>
  );
}
