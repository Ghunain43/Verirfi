// Bundles the extension into dist/. Load dist/ in chrome://extensions ("Load unpacked").
import { build } from "esbuild";
import { cpSync, mkdirSync, rmSync } from "node:fs";

rmSync("dist", { recursive: true, force: true });
mkdirSync("dist");

const common = { bundle: true, target: "chrome120", outdir: "dist", logLevel: "info" };
await build({ ...common, entryPoints: { background: "src/background.ts", popup: "src/popup.ts" }, format: "esm" });
await build({ ...common, entryPoints: { content: "src/content.ts" }, format: "iife" }); // content scripts are classic scripts

cpSync("manifest.json", "dist/manifest.json");
cpSync("src/popup.html", "dist/popup.html");
cpSync("icons", "dist/icons", { recursive: true });
console.log("Built dist/. Load it in chrome://extensions (Developer mode, Load unpacked).");
