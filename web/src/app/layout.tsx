import "./globals.css";
import type { Metadata } from "next";
import ParticleField from "@/components/ParticleField";
import Nav from "@/components/Nav";


export const metadata: Metadata = {
  title: "Verifi",
  description: "Check rumors before you share them.",
  icons: { icon: "/logo.png" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <ParticleField />
        <Nav />
        {children}
      </body>
    </html>
  );
}
