import Link from "next/link";
import Image from "next/image";

export default function Nav() {
  return (
    <nav className="sticky top-0 z-20 px-5 pt-4">
      <div className="glass mx-auto flex max-w-5xl items-center justify-between rounded-2xl px-4 py-2.5">
        <Link href="/" className="flex items-center gap-2.5">
          <Image src="/logo.png" alt="" width={32} height={32} className="rounded-lg" />
          <span className="text-lg font-semibold tracking-tight">Verifi</span>
        </Link>
        <div className="flex items-center gap-1 text-sm">
          <Link href="/radar" className="rounded-lg px-3 py-1.5 text-white/70 hover:bg-white/10 hover:text-white">Rumor Radar</Link>
          <Link href="/check" className="btn-primary rounded-lg px-4 py-1.5 font-medium">Check a claim</Link>
        </div>
      </div>
    </nav>
  );
}
