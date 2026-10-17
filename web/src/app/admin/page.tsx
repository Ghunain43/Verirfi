import Link from "next/link";
import { glass, pageBg } from "@/lib/ui";

export default function AdminPage() {
  return (
    <main className={pageBg}>
      <div className="mx-auto max-w-3xl space-y-4">
        <header className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Admin</h1>
          <Link href="/" className="text-sm text-indigo-300 hover:underline">← Home</Link>
        </header>
        <div className={`${glass} space-y-2`}>
          <h2 className="text-lg font-semibold">Admin data is not available yet</h2>
          <p className="text-sm text-white/70">
            The backend does not currently expose reporting, radar, or admin endpoints,
            so this page does not display sample or fabricated statistics.
          </p>
        </div>
      </div>
    </main>
  );
}
