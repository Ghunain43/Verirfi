"use client";
import { useRef } from "react";

// 3D tilt + moving highlight that follows the pointer.
export default function Tilt({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const move = (e: React.PointerEvent) => {
    const el = ref.current!, r = el.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5;
    el.style.transform = `perspective(900px) rotateX(${-y * 9}deg) rotateY(${x * 11}deg) translateY(-3px)`;
    el.style.setProperty("--mx", `${(x + 0.5) * 100}%`);
    el.style.setProperty("--my", `${(y + 0.5) * 100}%`);
  };
  return (
    <div ref={ref} onPointerMove={move} onPointerLeave={() => (ref.current!.style.transform = "")}
      className={`tilt transition-transform duration-200 ease-out ${className}`}>
      {children}
    </div>
  );
}
