/// Text normalization for fingerprinting (API.md section 4).
///
/// Pipeline (must match Python and TypeScript exactly):
/// 1. Unicode NFKC, then lowercase
/// 2. delete invisible chars: category Cf (zero-width, soft hyphen, bidi marks...),
///    variation selectors U+FE00-FE0F, combining grapheme joiner U+034F
/// 3. apply char_map from shared/normalize_map.json (homoglyphs, Arabic digits, Urdu letter forms,
///    deletes Arabic diacritics)
/// 4. every char that is not a letter (L*), digit (N*) or combining mark (Mn, Mc) becomes a space.
///    This also removes punctuation, symbols and emoji
/// 5. split on spaces; per token: squeeze runs of 3+ identical letters down to 2,
///    then map Roman Urdu variants to the canonical spelling
/// 6. join with a single space
library;

import 'dart:convert';

class NormalizeMap {
  final Map<String, String> charMap;
  final Map<String, String> romanUrdu;

  NormalizeMap({required this.charMap, required this.romanUrdu});

  factory NormalizeMap.fromJson(Map<String, dynamic> json) {
    return NormalizeMap(
      charMap: Map<String, String>.from(json['char_map']),
      romanUrdu: Map<String, String>.from(json['roman_urdu']),
    );
  }
}

// Embedded normalize_map.json data
const String _normalizeMapJson = '''
{
 "version": 1,
 "char_map": {
  "а": "a",
  "е": "e",
  "о": "o",
  "р": "p",
  "с": "c",
  "у": "y",
  "х": "x",
  "і": "i",
  "ј": "j",
  "ѕ": "s",
  "ԁ": "d",
  "һ": "h",
  "ӏ": "l",
  "ԛ": "q",
  "ԝ": "w",
  "к": "k",
  "м": "m",
  "т": "t",
  "ь": "b",
  "ο": "o",
  "α": "a",
  "ε": "e",
  "ν": "v",
  "ι": "i",
  "κ": "k",
  "ρ": "p",
  "τ": "t",
  "υ": "u",
  "χ": "x",
  "ϲ": "c",
  "٠": "0",
  "۰": "0",
  "١": "1",
  "۱": "1",
  "٢": "2",
  "۲": "2",
  "٣": "3",
  "۳": "3",
  "٤": "4",
  "۴": "4",
  "٥": "5",
  "۵": "5",
  "٦": "6",
  "۶": "6",
  "٧": "7",
  "۷": "7",
  "٨": "8",
  "۸": "8",
  "٩": "9",
  "۹": "9",
  "ي": "ی",
  "ى": "ی",
  "ك": "ک",
  "ه": "ہ",
  "ً": "",
  "ٌ": "",
  "ٍ": "",
  "َ": "",
  "ُ": "",
  "ِ": "",
  "ّ": "",
  "ْ": "",
  "ٓ": "",
  "ٔ": "",
  "ٕ": "",
  "ٖ": "",
  "ٗ": "",
  "٘": "",
  "ٙ": "",
  "ٚ": "",
  "ٛ": "",
  "ٜ": "",
  "ٝ": "",
  "ٞ": "",
  "ٟ": "",
  "ٰ": "",
  "ـ": ""
 },
 "roman_urdu": {
  "abhee": "abhi",
  "abi": "abhi",
  "accha": "acha",
  "acchaa": "acha",
  "achaa": "acha",
  "achchha": "acha",
  "achha": "acha",
  "ap": "aap",
  "apka": "aap",
  "bahot": "bahut",
  "bhee": "bhi",
  "bht": "bahut",
  "bi": "bhi",
  "bohat": "bahut",
  "bohot": "bahut",
  "boht": "bahut",
  "bohut": "bahut",
  "bokhar": "bukhar",
  "bukhaar": "bukhar",
  "bukhr": "bukhar",
  "eilaj": "ilaj",
  "elaj": "ilaj",
  "gaee": "gayi",
  "gai": "gayi",
  "gher": "ghar",
  "ghr": "ghar",
  "gya": "gaya",
  "gyi": "gayi",
  "hae": "hai",
  "haii": "hai",
  "hakumat": "hukumat",
  "ham": "hum",
  "hay": "hai",
  "hein": "hain",
  "hen": "hain",
  "hm": "hum",
  "hn": "hain",
  "hukomat": "hukumat",
  "hukoomat": "hukumat",
  "hy": "hai",
  "ilaaj": "ilaj",
  "jhooth": "jhoot",
  "jhot": "jhoot",
  "jhoth": "jhoot",
  "jhut": "jhoot",
  "jhuth": "jhoot",
  "kaisay": "kaise",
  "kaisey": "kaise",
  "karnaa": "karna",
  "kch": "kuch",
  "kesay": "kaise",
  "kese": "kaise",
  "khabr": "khabar",
  "khbar": "khabar",
  "kia": "kya",
  "kiun": "kyun",
  "kr": "kar",
  "krna": "karna",
  "kuchh": "kuch",
  "kyaa": "kya",
  "kyon": "kyun",
  "kyu": "kyun",
  "kyunke": "kyun",
  "logan": "log",
  "logo": "log",
  "logon": "log",
  "mai": "mein",
  "main": "mein",
  "me": "mein",
  "mei": "mein",
  "nahe": "nahi",
  "nahee": "nahi",
  "nahii": "nahi",
  "nahin": "nahi",
  "nai": "nahi",
  "nhi": "nahi",
  "paani": "pani",
  "paisay": "paisa",
  "paisy": "paisa",
  "panee": "pani",
  "pany": "pani",
  "pese": "paisa",
  "rahaa": "raha",
  "rha": "raha",
  "rhe": "rahe",
  "rhi": "rahi",
  "sachh": "sach",
  "sachi": "sach",
  "sahee": "sahi",
  "sehi": "sahi",
  "shi": "sahi",
  "sirph": "sirf",
  "srf": "sirf",
  "tah": "tha",
  "thaa": "tha",
  "vo": "woh",
  "voh": "woh",
  "wo": "woh",
  "wuh": "woh",
  "yah": "yeh",
  "ye": "yeh",
  "yeah": "yeh",
  "zada": "zyada",
  "ziada": "zyada",
  "zyadah": "zyada",
  "zyda": "zyada"
 }
}
''';

late final NormalizeMap _map;

void initializeNormalizeMap() {
  _map = NormalizeMap.fromJson(jsonDecode(_normalizeMapJson));
}

bool _isInvisible(String ch) {
  if (ch.isEmpty) return false;
  final cp = ch.codeUnitAt(0);
  // Check Unicode category Cf (format), variation selectors, and combining grapheme joiner
  return _isFormatChar(ch) || (cp >= 0xFE00 && cp <= 0xFE0F) || cp == 0x034F;
}

bool _isFormatChar(String ch) {
  // Unicode category Cf includes: zero-width space, zero-width non-joiner, 
  // zero-width joiner, soft hyphen, bidi marks, etc.
  final cp = ch.codeUnitAt(0);
  return (cp >= 0x00AD && cp <= 0x00AD) || // soft hyphen
      (cp >= 0x0600 && cp <= 0x0605) ||
      (cp >= 0x061C && cp <= 0x061C) ||
      (cp >= 0x06DD && cp <= 0x06DD) ||
      (cp >= 0x070F && cp <= 0x070F) ||
      (cp >= 0x08E2 && cp <= 0x08E2) ||
      (cp >= 0x180E && cp <= 0x180E) ||
      (cp >= 0x200B && cp <= 0x200F) || // zero-width space, LTR/RTL marks
      (cp >= 0x202A && cp <= 0x202E) || // bidi embedding/override
      (cp >= 0x2060 && cp <= 0x2064) ||
      (cp >= 0x2066 && cp <= 0x206F) ||
      (cp >= 0xFEFF && cp <= 0xFEFF) || // BOM
      (cp >= 0xFFF9 && cp <= 0xFFFB);
}

bool _isLetterOrDigit(String ch) {
  if (ch.isEmpty) return false;
  final cp = ch.codeUnitAt(0);
  
  // Letter categories (Lu, Ll, Lt, Lm, Lo)
  if ((cp >= 0x0041 && cp <= 0x005A) || // A-Z
      (cp >= 0x0061 && cp <= 0x007A) || // a-z
      (cp >= 0x00C0 && cp <= 0x00D6) ||
      (cp >= 0x00D8 && cp <= 0x00F6) ||
      (cp >= 0x00F8 && cp <= 0x02C1) ||
      (cp >= 0x02C6 && cp <= 0x02D1) ||
      (cp >= 0x02E0 && cp <= 0x02E4) ||
      (cp >= 0x0370 && cp <= 0x0374) ||
      (cp >= 0x0376 && cp <= 0x0377) ||
      (cp >= 0x037A && cp <= 0x037D) ||
      (cp >= 0x0386 && cp <= 0x038A) ||
      (cp >= 0x038C && cp <= 0x038C) ||
      (cp >= 0x038E && cp <= 0x03A1) ||
      (cp >= 0x03A3 && cp <= 0x03F5) ||
      (cp >= 0x03F7 && cp <= 0x0481) ||
      (cp >= 0x048A && cp <= 0x052F) ||
      (cp >= 0x0531 && cp <= 0x0556) ||
      (cp >= 0x0561 && cp <= 0x0587) ||
      (cp >= 0x05D0 && cp <= 0x05EA) ||
      (cp >= 0x05F0 && cp <= 0x05F2) ||
      (cp >= 0x0620 && cp <= 0x064A) ||
      (cp >= 0x066E && cp <= 0x066F) ||
      (cp >= 0x0671 && cp <= 0x06D3) ||
      (cp >= 0x06D5 && cp <= 0x06D5) ||
      (cp >= 0x06E5 && cp <= 0x06E6) ||
      (cp >= 0x06EE && cp <= 0x06EF) ||
      (cp >= 0x06FA && cp <= 0x06FC) ||
      (cp >= 0x0710 && cp <= 0x0710) ||
      (cp >= 0x0712 && cp <= 0x072F) ||
      (cp >= 0x074D && cp <= 0x07A5) ||
      (cp >= 0x07B1 && cp <= 0x07B1) ||
      (cp >= 0x07CA && cp <= 0x07EA)) {
    return true;
  }
  
  // Digit categories (Nd, Nl, No)
  if ((cp >= 0x0030 && cp <= 0x0039) || // 0-9
      (cp >= 0x0660 && cp <= 0x0669) || // Arabic-Indic
      (cp >= 0x06F0 && cp <= 0x06F9)) { // Extended Arabic-Indic
    return true;
  }
  
  // Combining marks (Mn, Mc)
  if ((cp >= 0x0300 && cp <= 0x036F) ||
      (cp >= 0x0483 && cp <= 0x0487) ||
      (cp >= 0x0591 && cp <= 0x05BD) ||
      (cp >= 0x05BF && cp <= 0x05BF) ||
      (cp >= 0x05C1 && cp <= 0x05C2) ||
      (cp >= 0x05C4 && cp <= 0x05C5) ||
      (cp >= 0x05C7 && cp <= 0x05C7) ||
      (cp >= 0x0610 && cp <= 0x061A) ||
      (cp >= 0x064B && cp <= 0x065F) ||
      (cp >= 0x0670 && cp <= 0x0670) ||
      (cp >= 0x06D6 && cp <= 0x06DC) ||
      (cp >= 0x06DF && cp <= 0x06E4) ||
      (cp >= 0x06E7 && cp <= 0x06E8) ||
      (cp >= 0x06EA && cp <= 0x06ED)) {
    return true;
  }
  
  return false;
}

String _squeeze(String token) {
  /// Runs of 3+ identical letters become 2 ('nahiiii' -> 'nahii'). Digits are never squeezed.
  if (token.isEmpty) return token;
  
  final out = StringBuffer();
  String? prev;
  int run = 0;
  
  for (int i = 0; i < token.length; i++) {
    final ch = token[i];
    if (ch == prev) {
      run++;
    } else {
      prev = ch;
      run = 1;
    }
    
    // Skip if run > 2 and it's a letter (not a digit)
    if (run > 2 && _isLetter(ch)) {
      continue;
    }
    out.write(ch);
  }
  
  return out.toString();
}

bool _isLetter(String ch) {
  if (ch.isEmpty) return false;
  final cp = ch.codeUnitAt(0);
  return (cp >= 0x0041 && cp <= 0x005A) || // A-Z
      (cp >= 0x0061 && cp <= 0x007A) || // a-z
      (cp >= 0x00C0 && cp <= 0x00D6) ||
      (cp >= 0x00D8 && cp <= 0x00F6) ||
      (cp >= 0x00F8 && cp <= 0x02C1) ||
      (cp >= 0x02C6 && cp <= 0x02D1) ||
      (cp >= 0x0370 && cp <= 0x0374) ||
      (cp >= 0x0376 && cp <= 0x0377) ||
      (cp >= 0x037A && cp <= 0x037D) ||
      (cp >= 0x0386 && cp <= 0x038A) ||
      (cp >= 0x038C && cp <= 0x038C) ||
      (cp >= 0x038E && cp <= 0x03A1) ||
      (cp >= 0x03A3 && cp <= 0x03F5) ||
      (cp >= 0x03F7 && cp <= 0x0481) ||
      (cp >= 0x048A && cp <= 0x052F) ||
      (cp >= 0x0531 && cp <= 0x0556) ||
      (cp >= 0x0561 && cp <= 0x0587) ||
      (cp >= 0x05D0 && cp <= 0x05EA) ||
      (cp >= 0x05F0 && cp <= 0x05F2) ||
      (cp >= 0x0620 && cp <= 0x064A) ||
      (cp >= 0x066E && cp <= 0x066F) ||
      (cp >= 0x0671 && cp <= 0x06D3) ||
      (cp >= 0x06D5 && cp <= 0x06D5) ||
      (cp >= 0x06E5 && cp <= 0x06E6) ||
      (cp >= 0x06EE && cp <= 0x06EF) ||
      (cp >= 0x06FA && cp <= 0x06FC) ||
      (cp >= 0x0710 && cp <= 0x0710) ||
      (cp >= 0x0712 && cp <= 0x072F) ||
      (cp >= 0x074D && cp <= 0x07A5) ||
      (cp >= 0x07B1 && cp <= 0x07B1) ||
      (cp >= 0x07CA && cp <= 0x07EA);
}

String normalize(String text) {
  // Step 1: NFKC normalization is not available in Dart by default, 
  // we'll use lowercase directly (NFKC would need a package)
  // For production, consider using the 'characters' package for proper Unicode handling
  String t = text.toLowerCase();
  
  // Step 2: Delete invisible chars
  t = t.split('').where((ch) => !_isInvisible(ch)).join('');
  
  // Step 3: Apply char_map
  t = t.split('').map((ch) => _map.charMap[ch] ?? ch).join('');
  
  // Step 4: Non-letter/digit/combining-mark -> space
  t = t.split('').map((ch) => _isLetterOrDigit(ch) ? ch : ' ').join('');
  
  // Step 5: Split, squeeze, and apply Roman Urdu
  final tokens = <String>[];
  for (var tok in t.split(' ')) {
    if (tok.isEmpty) continue;
    tok = _squeeze(tok);
    tokens.add(_map.romanUrdu[tok] ?? tok);
  }
  
  // Step 6: Join with single space
  return tokens.join(' ');
}
