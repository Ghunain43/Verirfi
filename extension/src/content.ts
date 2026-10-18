// Select text -> "Check" button -> result popup. All UI lives in a closed shadow root so page styles
// cannot break it and page scripts cannot read it. Remote text is only ever inserted with textContent.
import { initCompose } from "./compose";
import { rpc } from "./lib/messages";
import type { CheckView, RpcError } from "./lib/messages";

const MIN_LEN = 15;
const MAX_LEN = 2000;

const REASONS: Record<string, string> = {
  opinion: "an opinion",
  satire: "satire",
  religious: "a religious matter",
  prediction: "a prediction",
  too_vague: "too vague to check",
  no_claim: "not a factual claim",
};
const RATINGS: Record<string, string> = {
  false: "False",
  mostly_false: "Mostly false",
  mixed: "Mixed",
  mostly_true: "Mostly true",
  true: "True",
  unproven: "Unproven",
};
const STANCES: Record<string, string> = { supporting: "Supports", contradicting: "Contradicts", neutral: "Neutral" };

const CSS_TEXT = `
:host { all: initial; }
.btn { position: fixed; display: none; padding: 7px 12px; border: 0; border-radius: 16px; background: #1a73e8;
  color: #fff; font: 600 13px system-ui, sans-serif; cursor: pointer; box-shadow: 0 2px 8px rgba(0,0,0,.3); }
.btn:hover { background: #1558b0; }
.panel { position: fixed; display: none; width: 340px; max-width: calc(100vw - 16px); max-height: 70vh; overflow: auto;
  box-sizing: border-box; padding: 12px 14px; background: #fff; color: #202124; border-radius: 12px;
  box-shadow: 0 6px 24px rgba(0,0,0,.3); font: 14px/1.45 system-ui, sans-serif; }
.head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.brand { font-weight: 700; color: #1a73e8; }
.x { border: 0; background: none; font-size: 20px; line-height: 1; cursor: pointer; color: #5f6368; }
.claim { font-weight: 600; margin: 0 0 8px; }
.answer { margin: 0 0 4px; }
.muted { color: #5f6368; font-size: 12px; margin: 2px 0 8px; }
.fc { border: 1px solid #1a73e8; border-radius: 8px; padding: 8px; margin-bottom: 10px; background: #e8f0fe; }
.chip { display: inline-block; padding: 1px 8px; border-radius: 10px; font-size: 12px; font-weight: 600; margin-right: 6px;
  background: #e8eaed; color: #202124; }
.chip.contradicting, .chip.r-false, .chip.r-mostly_false { background: #fce8e6; color: #b31412; }
.chip.supporting, .chip.r-true, .chip.r-mostly_true { background: #e6f4ea; color: #137333; }
.ev { border-top: 1px solid #e8eaed; padding: 8px 0 0; margin-top: 8px; }
.ev a, .fc a { color: #1a73e8; word-break: break-word; }
.snippet { margin: 4px 0 0; color: #3c4043; font-size: 13px; }
.actions { margin-top: 10px; display: flex; gap: 8px; align-items: center; }
.link { border: 0; background: none; color: #1a73e8; cursor: pointer; padding: 0; font: inherit; text-decoration: underline; }
.err { color: #b31412; }
.note { font-size: 11px; color: #5f6368; margin-top: 8px; }
`;

function el<K extends keyof HTMLElementTagNameMap>(tag: K, cls?: string, text?: string): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (cls) node.className = cls;
  if (text !== undefined) node.textContent = text;
  return node;
}

function safeLink(url: string, label: string): HTMLElement {
  if (!url.startsWith("https://")) return el("span", undefined, label);
  const a = el("a", undefined, label);
  a.href = url;
  a.target = "_blank";
  a.rel = "noopener noreferrer";
  return a;
}

// ---- shadow DOM shell ----
const host = document.createElement("div");
host.id = "verifi-root";
host.style.cssText = "all:initial;position:fixed;top:0;left:0;z-index:2147483647;";
const shadow = host.attachShadow({ mode: "closed" });
const style = document.createElement("style");
style.textContent = CSS_TEXT;
const button = el("button", "btn", "Check with Verifi");
const panel = el("div", "panel");
shadow.append(style, button, panel);
const mount = () => document.documentElement.appendChild(host);
if (document.documentElement) mount();

let pending: { text: string; x: number; y: number } | null = null;
let lastMouse = { x: 0, y: 0 };

function hideAll(): void {
  button.style.display = "none";
  panel.style.display = "none";
  pending = null;
}

function place(node: HTMLElement, x: number, y: number, w: number, h: number): void {
  node.style.left = `${Math.max(8, Math.min(x, window.innerWidth - w - 8))}px`;
  node.style.top = `${Math.max(8, Math.min(y, window.innerHeight - h - 8))}px`;
}

function selectedText(): { text: string; x: number; y: number } | null {
  const active = document.activeElement;
  let text = "";
  if (active instanceof HTMLTextAreaElement || (active instanceof HTMLInputElement && active.type === "text")) {
    text = active.value.slice(active.selectionStart ?? 0, active.selectionEnd ?? 0);
  }
  const sel = window.getSelection();
  if (!text && sel) text = sel.toString();
  text = text.trim();
  if (text.length < MIN_LEN) return null;
  let x = lastMouse.x;
  let y = lastMouse.y + 16;
  if (sel && sel.rangeCount > 0) {
    const r = sel.getRangeAt(0).getBoundingClientRect();
    if (r.width > 0 || r.height > 0) {
      x = r.right;
      y = r.bottom + 8;
    }
  }
  return { text: text.slice(0, MAX_LEN), x, y };
}

function refreshButton(): void {
  const s = selectedText();
  if (!s) {
    if (panel.style.display === "none") hideAll();
    return;
  }
  pending = s;
  button.style.display = "block";
  place(button, s.x, s.y, 140, 34);
}

document.addEventListener("mousemove", (e) => (lastMouse = { x: e.clientX, y: e.clientY }), { passive: true });
document.addEventListener("mouseup", (e) => {
  if (e.composedPath().includes(host)) return;
  window.setTimeout(refreshButton, 10);
}, true);
document.addEventListener("keyup", (e) => {
  if (e.key === "Escape") hideAll();
  else if (e.shiftKey || e.key.startsWith("Arrow")) window.setTimeout(refreshButton, 10);
}, true);
document.addEventListener("mousedown", (e) => {
  if (!e.composedPath().includes(host)) hideAll();
}, true);
window.addEventListener("scroll", () => (button.style.display = "none"), { passive: true });

button.addEventListener("mousedown", (e) => e.preventDefault()); // keep the user's selection
button.addEventListener("click", () => {
  if (!pending) return;
  const { text, x, y } = pending;
  button.style.display = "none";
  void runCheck(text, x, y);
});

// ---- result panel ----
function openPanel(x: number, y: number): void {
  panel.replaceChildren();
  panel.style.display = "block";
  place(panel, x, y, 350, 220);
}

function header(): HTMLElement {
  const head = el("div", "head");
  const close = el("button", "x", "\u00d7");
  close.setAttribute("aria-label", "Close");
  close.addEventListener("click", hideAll);
  head.append(el("span", "brand", "Verifi"), close);
  return head;
}

function errorText(e: RpcError): string {
  switch (e.code) {
    case "network":
      return "Can't reach the Verifi server. Click the Verifi icon to check the server address.";
    case "rate_limited":
      return e.retryAfter
        ? `Too many requests. Try again in about ${Math.max(1, Math.ceil(e.retryAfter / 60))} minute(s).`
        : "Too many requests. Try again later.";
    case "invalid_input":
      return "That text can't be checked (empty or over 2000 characters).";
    case "timeout":
      return "The check took too long. Try selecting a shorter text.";
    case "upstream_failed":
      return "The research service is unavailable right now. Try again in a moment.";
    default:
      return e.message || "Something went wrong.";
  }
}

async function runCheck(text: string, x: number, y: number): Promise<void> {
  openPanel(x, y);
  panel.append(header(), el("p", "muted", "Checking\u2026"));
  try {
    const view = await rpc<CheckView>({ type: "check", text });
    render(view);
  } catch (err) {
    panel.replaceChildren(header(), el("p", "err", errorText(err as RpcError)));
  }
}

function render(v: CheckView): void {
  panel.replaceChildren(header());
  const claim = el("p", "claim", v.claim);
  claim.dir = "auto";
  panel.append(claim);

  for (const f of v.factchecks) {
    const box = el("div", "fc");
    const top = el("div");
    top.append(el("span", `chip r-${f.rating}`, RATINGS[f.rating] ?? f.rating), el("strong", undefined, `Fact-checked by ${f.publisher}`));
    const summary = el("p", "snippet", f.summary);
    summary.dir = "auto";
    const src = el("p", "snippet");
    src.append(safeLink(f.source_url, "Read their full check"));
    box.append(top, summary, src);
    panel.append(box);
  }

  if (!v.checkable) {
    panel.append(el("p", "answer", `We can't check this: it looks like ${REASONS[v.reason_unchecked ?? ""] ?? "something we can't verify"}.`));
  } else if (v.likely_answer) {
    const a = el("p", "answer", v.likely_answer);
    a.dir = "auto";
    panel.append(a);
    if (v.confidence_high > 0) {
      const lo = Math.round(v.confidence_low * 100);
      const hi = Math.round(v.confidence_high * 100);
      panel.append(el("p", "muted", `Confidence range: ${lo}% to ${hi}%`));
    }
  } else if (v.factchecks.length === 0) {
    panel.append(el("p", "answer", "Not enough evidence to say."));
  }

  for (const e of v.evidence.slice(0, 4)) {
    const box = el("div", "ev");
    const line = el("div");
    line.append(el("span", `chip ${e.stance}`, STANCES[e.stance] ?? e.stance));
    if (e.publisher) line.append(el("strong", undefined, `${e.publisher} `));
    line.append(safeLink(e.url, e.title));
    box.append(line);
    if (e.snippet) {
      const s = el("p", "snippet", e.snippet);
      s.dir = "auto";
      box.append(s);
    }
    panel.append(box);
  }

  const actions = el("div", "actions");
  if (v.checkable) {
    const rep = el("button", "link", "Report as a rumor (anonymous)");
    rep.addEventListener("click", async () => {
      rep.disabled = true;
      try {
        await rpc({ type: "report", fingerprint: v.fingerprint });
        rep.textContent = "Thanks. Only a fingerprint was sent.";
      } catch (err) {
        rep.textContent = errorText(err as RpcError);
      }
    });
    actions.append(rep);
  }
  panel.append(actions);
  const note =
    v.source === "cache"
      ? "From results already checked. Your text did not leave your browser."
      : `Checked in ${((v.took_ms ?? 0) / 1000).toFixed(1)}s. An AI estimate, not a verdict: read the sources.`;
  panel.append(el("p", "note", note));
}

initCompose();
