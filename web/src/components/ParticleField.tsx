"use client";
import { useEffect, useRef } from "react";

type P = { x: number; y: number; z: number; vx: number; vy: number };

// Fixed full-screen canvas: drifting particles with depth, parallax and mouse repulsion.
export default function ParticleField() {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const c = ref.current!;
    const ctx = c.getContext("2d")!;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const m = { x: -999, y: -999, nx: 0, ny: 0 };
    let w = 0, h = 0, raf = 0, ps: P[] = [];

    const init = () => {
      w = window.innerWidth; h = window.innerHeight;
      c.width = w * dpr; c.height = h * dpr; c.style.width = `${w}px`; c.style.height = `${h}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const n = Math.min(120, Math.floor((w * h) / 13000));
      ps = Array.from({ length: n }, () => ({
        x: Math.random() * w, y: Math.random() * h, z: Math.random() * 0.9 + 0.1,
        vx: (Math.random() - 0.5) * 0.3, vy: (Math.random() - 0.5) * 0.3,
      }));
    };
    const onMove = (e: PointerEvent) => { m.x = e.clientX; m.y = e.clientY; m.nx = e.clientX / w - 0.5; m.ny = e.clientY / h - 0.5; };
    const onLeave = () => { m.x = m.y = -999; };

    const frame = () => {
      ctx.clearRect(0, 0, w, h);
      const pts = ps.map((p) => {
        if (!still) {
          p.x += p.vx * p.z * 2; p.y += p.vy * p.z * 2;
          const dx = p.x - m.x, dy = p.y - m.y, d = Math.hypot(dx, dy);
          if (d < 150 && d > 0) { const f = (150 - d) / 150; p.x += (dx / d) * f * 3 * p.z; p.y += (dy / d) * f * 3 * p.z; }
          if (p.x < -20) p.x = w + 20; if (p.x > w + 20) p.x = -20;
          if (p.y < -20) p.y = h + 20; if (p.y > h + 20) p.y = -20;
        }
        return { x: p.x - m.nx * 70 * p.z, y: p.y - m.ny * 70 * p.z, z: p.z }; // nearer particles shift more
      });
      for (let i = 0; i < pts.length; i++) {
        for (let j = i + 1; j < pts.length; j++) {
          const d = Math.hypot(pts[i].x - pts[j].x, pts[i].y - pts[j].y);
          if (d < 120) {
            ctx.strokeStyle = `hsla(${190 + (pts[i].x / w) * 85},90%,70%,${(1 - d / 120) * 0.18})`;
            ctx.beginPath(); ctx.moveTo(pts[i].x, pts[i].y); ctx.lineTo(pts[j].x, pts[j].y); ctx.stroke();
          }
        }
      }
      for (const p of pts) {
        const hue = 190 + (p.x / w) * 85; // cyan to violet, like the logo
        ctx.fillStyle = `hsla(${hue},95%,70%,0.12)`;
        ctx.beginPath(); ctx.arc(p.x, p.y, 2 + p.z * 5, 0, 7); ctx.fill();
        ctx.fillStyle = `hsla(${hue},95%,75%,${0.4 + p.z * 0.5})`;
        ctx.beginPath(); ctx.arc(p.x, p.y, 0.6 + p.z * 1.6, 0, 7); ctx.fill();
      }
      if (!still) raf = requestAnimationFrame(frame);
    };

    init(); frame();
    window.addEventListener("resize", init);
    window.addEventListener("pointermove", onMove);
    document.addEventListener("pointerleave", onLeave);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", init);
      window.removeEventListener("pointermove", onMove);
      document.removeEventListener("pointerleave", onLeave);
    };
  }, []);

  return <canvas ref={ref} aria-hidden className="pointer-events-none fixed inset-0 z-0" />;
}
