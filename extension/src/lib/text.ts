export interface Span {
  start: number;
  end: number;
  text: string;
}

/** Split text into sentences (Latin and Urdu/Arabic punctuation), keeping character offsets. */
export function splitSentences(full: string): Span[] {
  const out: Span[] = [];
  const re = /[^.!?\u06d4\u061f\n]+[.!?\u06d4\u061f]*/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(full)) !== null) {
    const raw = m[0];
    const lead = raw.length - raw.trimStart().length;
    const text = raw.trim();
    if (text) out.push({ start: m.index + lead, end: m.index + lead + text.length, text });
  }
  return out;
}
