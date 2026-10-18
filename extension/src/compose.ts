// Underlines sentences you type that match an already-checked claim (compose-box underline).
// Opt-in: it asks the server for the 4-character prefix of each sentence you type, so it is off by default.
// Works in contenteditable boxes (WhatsApp Web, Gmail, Facebook, X ...) via the CSS Custom Highlight API.
import { computeFingerprint, prefixOf } from "./lib/fingerprint";
import { rpc } from "./lib/messages";
import type { FlaggedEntry } from "./lib/messages";
import { hamming } from "./lib/simhash";
import { splitSentences } from "./lib/text";

const FLAGGED = "verifi-flagged";
const KNOWN = "verifi-known";
const MAX_DISTANCE = 3;
const MAX_SENTENCES_PER_SCAN = 8;
const EDITABLE = '[contenteditable=""],[contenteditable="true"],[contenteditable="plaintext-only"]';

type HighlightRegistry = Map<string, unknown>;
type HighlightCtor = new (...ranges: Range[]) => unknown;

function textNodes(root: Element): Text[] {
  const out: Text[] = [];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  while (walker.nextNode()) out.push(walker.currentNode as Text);
  return out;
}

function locate(nodes: Text[], starts: number[], offset: number): [Text, number] | null {
  for (let i = nodes.length - 1; i >= 0; i--) {
    if (offset >= starts[i]) return [nodes[i], Math.min(offset - starts[i], nodes[i].data.length)];
  }
  return null;
}

export function initCompose(): void {
  const registry = (CSS as unknown as { highlights?: HighlightRegistry }).highlights;
  const HighlightClass = (window as unknown as { Highlight?: HighlightCtor }).Highlight;
  if (!registry || !HighlightClass) return; // older browsers: feature unavailable
  const reg: HighlightRegistry = registry;
  const Highlight: HighlightCtor = HighlightClass;

  const style = document.createElement("style");
  style.textContent =
    `::highlight(${FLAGGED}){text-decoration:underline wavy #d93025;text-decoration-thickness:2px}` +
    `::highlight(${KNOWN}){text-decoration:underline dotted #f29900;text-decoration-thickness:2px}`;
  document.head.appendChild(style);

  let enabled = false;
  let timer: number | undefined;
  let scanId = 0;

  const clear = () => {
    reg.delete(FLAGGED);
    reg.delete(KNOWN);
  };
  const apply = (settings: unknown) => {
    enabled = !!(settings as { composeUnderline?: boolean } | undefined)?.composeUnderline;
    if (!enabled) clear();
  };
  void chrome.storage.local.get("settings").then((r) => apply(r.settings));
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && changes.settings) apply(changes.settings.newValue);
  });

  async function scan(root: Element): Promise<void> {
    const id = ++scanId;
    const nodes = textNodes(root);
    const starts: number[] = [];
    let full = "";
    for (const n of nodes) {
      starts.push(full.length);
      full += n.data;
    }
    const spans = splitSentences(full)
      .filter((s) => s.text.length >= 25 && s.text.length <= 500)
      .slice(0, MAX_SENTENCES_PER_SCAN);
    const flagged: Range[] = [];
    const known: Range[] = [];
    for (const s of spans) {
      const fp = computeFingerprint(s.text);
      let entries: FlaggedEntry[];
      try {
        entries = await rpc<FlaggedEntry[]>({ type: "lookupBucket", prefix: prefixOf(fp) });
      } catch {
        continue;
      }
      if (id !== scanId) return; // the user kept typing: a newer scan supersedes this one
      const hits = entries.filter((e) => hamming(e.fingerprint, fp) <= MAX_DISTANCE);
      if (hits.length === 0) continue;
      const a = locate(nodes, starts, s.start);
      const b = locate(nodes, starts, s.end);
      if (!a || !b) continue;
      const range = document.createRange();
      range.setStart(a[0], a[1]);
      range.setEnd(b[0], b[1]);
      (hits.some((h) => h.flagged) ? flagged : known).push(range);
    }
    if (id !== scanId) return;
    reg.set(FLAGGED, new Highlight(...flagged));
    reg.set(KNOWN, new Highlight(...known));
  }

  document.addEventListener(
    "input",
    (e) => {
      if (!enabled || !(e.target instanceof Element)) return;
      const root = e.target.closest(EDITABLE);
      if (!root) return;
      window.clearTimeout(timer);
      timer = window.setTimeout(() => void scan(root), 1000);
    },
    true,
  );
}
