import { quickCheck, getRadar, ApiError } from "./api.js";

const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; };
const safe = (u) => (/^https?:\/\//i.test(u || "") ? u : null);

const REASON = {
  opinion: ["Opinion", "This says how someone feels. There is no fact to verify. If it hides a factual claim, paste just that part."],
  satire: ["Satire or joke", "This reads like humor, so it isn't rated true or false."],
  religious: ["Matter of faith", "A belief or teaching that facts can't confirm or refute."],
  prediction: ["Prediction", "It hasn't happened yet, so it can only be checked afterwards."],
  too_vague: ["Too vague", "No specific person, place, number or event to search for. Add who, what and when."],
  no_claim: ["No checkable claim", "No statement about the world was found. Paste the sentence that makes the claim."],
};
const STANCE = { supporting: ["Supports", "green"], contradicting: ["Contradicts", "rose"], neutral: ["Neutral", ""] };

function errorText(e) {
  if (!(e instanceof ApiError)) return "Something went wrong. Please try again.";
  switch (e.code) {
    case "timeout": return "The check took too long. The server may be waking up, so try again.";
    case "network": return "Couldn't reach the server. Check your connection and try again.";
    case "rate_limited": return `Limit reached (20 checks per hour).${e.retryAfter ? ` Try again in about ${Math.ceil(e.retryAfter / 60)} min.` : ""}`;
    case "upstream_failed": return "The research service isn't responding right now. Try again shortly.";
    case "invalid_input": return "That text can't be checked. It must be 1 to 2000 characters.";
    default: return "Something went wrong. Please try again.";
  }
}

function tone(answer) {
  const a = answer.toLowerCase();
  if (/false|misleading|contradict/.test(a)) return ["Likely false", "rose"];
  if (/true|support|accurate/.test(a)) return ["Likely true", "green"];
  return ["Unclear", "amber"];
}

function skeleton() { const d = el("div", "card"); ["40%", "85%", "100%"].forEach((w) => { const s = el("div", "sk"); s.style.width = w; d.append(s); }); d.append(el("p", "muted", "Searching sources. This usually takes a few seconds.")); return d; }

function renderResult(r) {
  const card = el("div", "card");
  if (!r.checkable) {
    const [title, why] = REASON[r.reason_unchecked] || REASON.no_claim;
    card.append(el("span", "chip sky", `Not rated · ${title}`), el("div", "label", "Why"), el("div", "", why), el("div", "muted", `Text we read: ${r.claim}`));
    return card;
  }
  const answer = (r.likely_answer || "").trim() || "Not enough evidence to say";
  const [chip, cls] = tone(answer);
  const low = Math.round(r.confidence_low * 100), high = Math.round(r.confidence_high * 100);
  const n = (s) => r.evidence.filter((e) => e.stance === s).length;
  const bar = el("div", "bar"), fill = el("i"); fill.style.left = `${low}%`; fill.style.width = `${Math.max(high - low, 1)}%`; bar.append(fill);
  card.append(
    el("span", `chip ${cls}`, chip), el("span", "muted", `  ${r.cached ? "From cache" : "Fresh check"} · ${(r.took_ms / 1000).toFixed(1)}s`),
    el("div", "label", "Claim"), el("div", "", r.claim),
    el("div", "label", "Likely answer"), el("div", "answer", answer),
    el("div", "label", `Confidence range · ${low}% to ${high}%`), bar,
    el("div", "label", `Why · ${r.evidence.length} source${r.evidence.length === 1 ? "" : "s"} (${n("contradicting")} contradict, ${n("supporting")} support)`),
  );
  if (!r.evidence.length) card.append(el("div", "muted", "No evidence found."));
  for (const e of r.evidence) {
    const href = safe(e.url);
    const a = el(href ? "a" : "div", "ev");
    if (href) { a.href = href; a.target = "_blank"; a.rel = "noopener noreferrer"; }
    const [label, scls] = STANCE[e.stance] || STANCE.neutral;
    const meta = el("small", "", `${e.publisher || "Unknown"} · `); meta.append(el("span", `chip ${scls}`, label), ` · Quality ${Math.round(e.quality * 100)}%`);
    a.append(el("b", "", e.title), meta);
    if (e.snippet) a.append(el("small", "", e.snippet));
    card.append(a);
  }
  return card;
}

let busy = false;
async function run() {
  const text = $("text").value.trim();
  if (!text || busy) return;
  busy = true; $("go").disabled = true; $("go").textContent = "Checking...";
  $("out").replaceChildren(skeleton());
  try { $("out").replaceChildren(renderResult(await quickCheck(text))); }
  catch (e) { $("out").replaceChildren(el("div", "card err", errorText(e))); }
  finally { busy = false; $("go").textContent = "Check"; $("go").disabled = !$("text").value.trim(); }
}

async function loadRadar() {
  const box = $("radar");
  box.replaceChildren(skeleton());
  try {
    const items = await getRadar();
    if (!items.length) return box.replaceChildren(el("div", "card muted", "No trending rumors right now."));
    box.replaceChildren(...items.map((it, i) => {
      const web = it.origin === "web", href = safe(it.source_url);
      const c = el("div", "card");
      c.append(el("span", `chip ${web ? "rose" : "indigo"}`, web ? "Rated false by fact-checkers" : `Spreading · ${it.reports} checks`), el("div", "answer", `${i + 1}. ${it.claim}`));
      c.append(el("div", "why", it.why || (web ? "Fact-checkers rated this claim false." : "Many people on different networks checked this claim.")));
      if (web && href) { const a = el("a", "src", `Source: ${it.publisher || "fact-check"} ↗`); a.href = href; a.target = "_blank"; a.rel = "noopener noreferrer"; c.append(a); }
      return c;
    }));
  } catch (e) { box.replaceChildren(el("div", "card err", errorText(e))); }
}

function show(tab) {
  $("view-check").hidden = tab !== "check"; $("view-radar").hidden = tab !== "radar";
  $("tab-check").classList.toggle("active", tab === "check"); $("tab-radar").classList.toggle("active", tab === "radar");
  if (tab === "radar" && !$("radar").children.length) loadRadar();
}

$("text").addEventListener("input", () => { $("count").textContent = `${$("text").value.length}/2000`; $("go").disabled = busy || !$("text").value.trim(); });
$("text").addEventListener("keydown", (e) => { if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) run(); });
$("go").addEventListener("click", run);
$("tab-check").addEventListener("click", () => show("check"));
$("tab-radar").addEventListener("click", () => show("radar"));

(async function init() {
  const p = new URLSearchParams(location.search);
  let text = p.get("text") || "";
  if (!text) { // toolbar click: pick up the text selected on the current page, if any
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      const [res] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: () => String(getSelection()) });
      text = (res?.result || "").trim().slice(0, 2000);
    } catch {}
  }
  $("text").value = text; $("text").dispatchEvent(new Event("input"));
  $("text").focus();
  if (text && p.get("auto") === "1") run();
})();
