import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Verifi",
  description: "Check rumors before you share them.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}