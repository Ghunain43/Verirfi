import Link from "next/link";
import Image from "next/image";
import Tilt from "@/components/Tilt";

const FEATURES = [
  { t: "Paste anything", d: "A forwarded message, a headline, a screenshot caption. We pull out the claim that can actually be checked." },
  { t: "Sources, not opinions", d: "Every answer shows the evidence behind it and how sure we are. Opinions and jokes are left alone." },
  { t: "Rumor Radar", d: "See which false claims are spreading right now, and why each one is on the list." },
];

export default function Home() {
  return (
    <main className="relative z-10 px-5 pb-20 text-white">
      <section className="mx-auto flex max-w-3xl flex-col items-center pt-14 text-center sm:pt-20">
        <div className="float relative">
          <div className="absolute inset-0 -z-10 scale-125 rounded-full bg-indigo-500/30 blur-3xl" />
          <Image src="/logo.png" alt="Verifi" width={116} height={116} priority className="rounded-[28px] shadow-2xl" />
        </div>
        <h1 className="mt-8 text-4xl font-bold leading-tight tracking-tight sm:text-6xl">
          Check it before <span className="grad-text">you share it.</span>
        </h1>
        <p className="mt-5 max-w-xl text-base text-white/60 sm:text-lg">
          Verifi weighs a claim against real sources in seconds and shows you the evidence. Nothing you paste is saved.
        </p>
        <div className="mt-9 flex flex-wrap justify-center gap-3">
          <Link href="/check" className="btn-primary rounded-2xl px-7 py-3.5 text-base font-semibold">Check a claim</Link>
          <Link href="/radar" className="btn-ghost rounded-2xl px-7 py-3.5 text-base font-medium">View Rumor Radar</Link>
        </div>
        <div className="mt-4 flex flex-wrap justify-center gap-3 text-sm">
          <Link href="/factcheck" className="btn-ghost rounded-xl px-5 py-2.5 text-white/70">🔒 Fact-check</Link>
          <Link href="/admin" className="btn-ghost rounded-xl px-5 py-2.5 text-white/70">🔒 Admin</Link>
        </div>
      </section>

      <section className="mx-auto mt-24 grid max-w-5xl gap-5 sm:grid-cols-3">
        {FEATURES.map((f, i) => (
          <Tilt key={f.t} className="glass rounded-3xl p-6">
            <div className="grad-text text-sm font-semibold">0{i + 1}</div>
            <div className="mt-2 text-lg font-semibold">{f.t}</div>
            <p className="mt-2 text-sm leading-relaxed text-white/55">{f.d}</p>
          </Tilt>
        ))}
      </section>
    </main>
  );
}
