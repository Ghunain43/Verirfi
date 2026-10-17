import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads text out of a screenshot, fully on the device (ML Kit, bundled Latin
/// model). The image never leaves the phone.
///
/// Limitation: ML Kit has no Urdu-script (Nastaliq) model. English and Roman
/// Urdu screenshots work; Urdu-script ones come back empty or garbled.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  // WhatsApp screen furniture that is not part of the message.
  static final RegExp _noise = RegExp(
    r'^(\d{1,2}[:.]\d{2}\s?(am|pm)?|forwarded( many times)?|read more|'
    r'today|yesterday|type a message|message)$',
    caseSensitive: false,
  );

  Future<String> readImage(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return _clean(result.text);
    } finally {
      await recognizer.close();
    }
  }

  static String _clean(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !_noise.hasMatch(l));
    return lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
