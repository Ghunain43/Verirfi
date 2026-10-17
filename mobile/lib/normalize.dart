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
import 'package:unorm_dart/unorm_dart.dart' as unorm;

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

late NormalizeMap _map;
bool _mapReady = false;

void initializeNormalizeMap() {
  if (_mapReady) return;
  _map = NormalizeMap.fromJson(jsonDecode(_normalizeMapJson));
  _mapReady = true;
}

// Same Unicode categories as the Python version.
final RegExp _formatRe = RegExp(r'^\p{Cf}$', unicode: true);
final RegExp _keepRe = RegExp(r'^[\p{L}\p{N}\p{Mn}\p{Mc}]$', unicode: true);
final RegExp _letterRe = RegExp(r'^\p{L}$', unicode: true);

bool _isInvisible(int cp, String ch) =>
    _formatRe.hasMatch(ch) || (cp >= 0xFE00 && cp <= 0xFE0F) || cp == 0x034F;

/// Runs of 3+ identical letters become 2. Digits are never squeezed.
String _squeeze(String token) {
  final out = StringBuffer();
  int? prev;
  var run = 0;
  for (final cp in token.runes) {
    if (cp == prev) {
      run++;
    } else {
      prev = cp;
      run = 1;
    }
    final ch = String.fromCharCode(cp);
    if (run > 2 && _letterRe.hasMatch(ch)) continue;
    out.write(ch);
  }
  return out.toString();
}

String normalize(String text) {
  initializeNormalizeMap();

  // 1. NFKC, then lowercase
  final t = unorm.nfkc(text).toLowerCase();

  // 2-4: delete invisible chars, apply char_map, non-letter/digit/mark -> space
  final spaced = StringBuffer();
  for (final cp in t.runes) {
    final ch = String.fromCharCode(cp);
    if (_isInvisible(cp, ch)) continue;
    final mapped = _map.charMap[ch] ?? ch;
    for (final m in mapped.runes) {
      final c = String.fromCharCode(m);
      spaced.write(_keepRe.hasMatch(c) ? c : ' ');
    }
  }

  // 5-6: squeeze, Roman Urdu canonical spelling, join with single spaces
  final tokens = <String>[];
  for (var tok in spaced.toString().split(' ')) {
    if (tok.isEmpty) continue;
    tok = _squeeze(tok);
    tokens.add(_map.romanUrdu[tok] ?? tok);
  }
  return tokens.join(' ');
}
