"use client";
import { useEffect, useState } from "react";
import Link from "next/link";

const PIN = process.env.NEXT_PUBLIC_ADMIN_PIN || "36226";
const KEY = "verifi_unlocked";

export default function Gate({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false);
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState("");
  const [error, setError] = useState(false);

  useEffect(() => {
    try { setOpen(sessionStorage.getItem(KEY) === "1"); } catch {}
    setReady(true);
  }, []);

  function submit(e: React.FormEvent) {
    e.preventDefault();
    if (value === PIN) {
      try { sessionStorage.setItem(KEY, "1"); } catch {}
      setOpen(true);
    } else {
      setError(true);
      setValue("");
    }
  }

  if (!ready) return null;
  if (open) return <>{children}</>;

  return (
    <main className="relative z-10 flex min-h-[calc(100vh-72px)] items-center justify-center px-5">
      <form onSubmit={submit} className="glass w-full max-w-sm space-y-4 rounded-3xl p-7 text-center">
        <h1 className="text-2xl font-bold">Restricted <span className="grad-text">area</span></h1>
        <p className="text-sm text-white/55">Enter the access PIN to continue.</p>
        <input
          autoFocus
          type="password"
          inputMode="numeric"
          value={value}
          onChange={(e) => { setValue(e.target.value); setError(false); }}
          placeholder="PIN"
          className="w-full rounded-xl border border-white/15 bg-white/5 px-4 py-3 text-center text-lg tracking-[0.4em] outline-none focus:border-indigo-400"
        />
        {error && <p className="text-sm text-rose-300">Wrong PIN. Try again.</p>}
        <button type="submit" className="btn-primary w-full rounded-xl py-3 font-semibold">Unlock</button>
        <Link href="/" className="block text-xs text-white/40 hover:text-white/70">Back to home</Link>
      </form>
    </main>
  );
}
