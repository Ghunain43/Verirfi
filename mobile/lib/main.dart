import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'api_client.dart';
import 'glass.dart';
import 'normalize.dart';
import 'ocr.dart';
import 'result_card.dart';
import 'splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the normalize map for fingerprinting
  initializeNormalizeMap();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: C.bg1,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const VerifiApp());
}

class VerifiApp extends StatelessWidget {
  const VerifiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Verifi',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: C.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: C.bg1,
      ),
      home: SplashGate(next: const Home()),
    );
  }
}

enum Phase { idle, loading, done, error }

/// What the error card shows for a failed check.
class _ErrInfo {
  const _ErrInfo({
    required this.icon,
    required this.title,
    required this.message,
    this.retryAfter,
    this.canRetry = true,
  });
  final IconData icon;
  final String title;
  final String message;
  final int? retryAfter;
  final bool canRetry;
}

const int _maxChars = 2000;

_ErrInfo _describe(Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'rate_limited':
        return _ErrInfo(
          icon: Icons.hourglass_top_rounded,
          title: 'Too many checks',
          message:
              'You have reached the check limit for now. '
              'You can try again when the timer ends.',
          retryAfter: e.retryAfter ?? 30,
        );
      case 'invalid_input':
        return const _ErrInfo(
          icon: Icons.edit_off_rounded,
          title: 'Can\u2019t check that text',
          message:
              'The text is empty or longer than 2000 characters. '
              'Shorten it and try again.',
          canRetry: false,
        );
      case 'upstream_failed':
        return const _ErrInfo(
          icon: Icons.cloud_off_rounded,
          title: 'Sources are busy',
          message:
              'Our fact-checking sources didn\u2019t respond. '
              'This is usually temporary, so try again.',
        );
      case 'timeout':
        return const _ErrInfo(
          icon: Icons.timer_off_rounded,
          title: 'That took too long',
          message: 'The check ran out of time. Try again, or shorten the text.',
        );
      case 'invalid_token':
        return const _ErrInfo(
          icon: Icons.lock_reset_rounded,
          title: 'Couldn\u2019t start a session',
          message:
              'Verifi couldn\u2019t get a new anonymous session. '
              'Try again.',
        );
    }
    return const _ErrInfo(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message: 'The server returned an unexpected error. Try again.',
    );
  }
  if (e is TimeoutException) {
    return const _ErrInfo(
      icon: Icons.timer_off_rounded,
      title: 'That took too long',
      message: 'The server didn\u2019t answer in time. Try again.',
    );
  }
  final s = e.toString();
  if (e is http.ClientException ||
      s.contains('SocketException') ||
      s.contains('Failed host lookup')) {
    return const _ErrInfo(
      icon: Icons.wifi_off_rounded,
      title: 'No connection',
      message:
          'Can\u2019t reach the Verifi server. '
          'Check your internet connection and try again.',
    );
  }
  return const _ErrInfo(
    icon: Icons.error_outline_rounded,
    title: 'Something went wrong',
    message: 'Please try again.',
  );
}

String _fmtSeconds(int s) =>
    s >= 60 ? '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s' : '${s}s';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _api = ApiClient();
  final _ctrl = TextEditingController();
  StreamSubscription? _sub;
  Timer? _cooldownTimer;
  Phase _phase = Phase.idle;
  Map<String, dynamic>? _result;
  _ErrInfo? _err;
  int _cooldown = 0;
  bool _scanning = false;
  String _lastText = '';
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared);
    ReceiveSharingIntent.instance.getInitialMedia().then(_onShared);
  }

  void _onShared(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text && f.path.trim().isNotEmpty) {
        _ctrl.text = f.path;
        _check(f.path);
        ReceiveSharingIntent.instance.reset();
        break;
      }
      if (f.type == SharedMediaType.image && f.path.isNotEmpty) {
        _scan(f.path);
        ReceiveSharingIntent.instance.reset();
        break;
      }
    }
  }

  Future<void> _pickAndScan() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    await _scan(x.path);
  }

  /// Reads a screenshot on the device, puts the text in the box and checks it.
  Future<void> _scan(String path) async {
    final id = ++_req;
    _cooldownTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _cooldown = 0;
      _scanning = true;
      _phase = Phase.loading;
      _result = null;
    });
    try {
      final text = await OcrService.instance.readImage(path);
      if (!mounted || id != _req) return;
      if (text.length < 8) {
        setState(() {
          _scanning = false;
          _err = const _ErrInfo(
            icon: Icons.image_not_supported_rounded,
            title: 'No readable text found',
            message:
                'Scanning works for English and Roman Urdu. Urdu script '
                'isn\u2019t supported yet, so paste that text instead.',
            canRetry: false,
          );
          _phase = Phase.error;
        });
        return;
      }
      _ctrl.text = text;
      await _check(text);
    } catch (e) {
      debugPrint('scan failed: $e');
      if (!mounted || id != _req) return;
      setState(() {
        _scanning = false;
        _err = const _ErrInfo(
          icon: Icons.image_not_supported_rounded,
          title: 'Couldn\u2019t read that image',
          message: 'Try another screenshot, or paste the text instead.',
          canRetry: false,
        );
        _phase = Phase.error;
      });
    }
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _check(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final id = ++_req;
    _lastText = t;
    _cooldownTimer?.cancel();

    // Don't send text the server will reject anyway.
    if (t.length > _maxChars) {
      setState(() {
        _cooldown = 0;
        _err = const _ErrInfo(
          icon: Icons.edit_off_rounded,
          title: 'That\u2019s too long',
          message:
              'Verifi checks up to 2000 characters at a time. '
              'Trim the message down to the main claim and try again.',
          canRetry: false,
        );
        _phase = Phase.error;
      });
      return;
    }

    setState(() {
      _cooldown = 0;
      _scanning = false;
      _phase = Phase.loading;
      _result = null;
    });
    try {
      final r = await _api.quickCheck(t);
      if (!mounted || id != _req) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _result = r;
        _phase = Phase.done;
      });
    } catch (e) {
      debugPrint('quickCheck failed: $e');
      if (!mounted || id != _req) return;
      final info = _describe(e);
      setState(() {
        _err = info;
        _phase = Phase.error;
      });
      if (info.retryAfter != null) _startCooldown(info.retryAfter!);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cooldownTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _errorCard() {
    final e = _err!;
    final waiting = _cooldown > 0;
    return FadeSlideIn(
      child: GlassCard(
        radius: 28,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(e.icon, size: 38, color: C.amber),
            const SizedBox(height: 12),
            Text(
              e.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: C.textHi,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              e.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: C.textLo,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
            if (e.canRetry) ...[
              const SizedBox(height: 18),
              GradientButton(
                label: waiting
                    ? 'Try again in ${_fmtSeconds(_cooldown)}'
                    : 'Try again',
                icon: waiting
                    ? Icons.hourglass_top_rounded
                    : Icons.refresh_rounded,
                onPressed: waiting ? null : () => _check(_lastText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case Phase.idle:
        return const FadeSlideIn(child: _Hint());
      case Phase.loading:
        return _Skeleton(
          label: _scanning
              ? 'Reading the screenshot\u2026'
              : 'Searching trusted sources\u2026',
        );
      case Phase.error:
        return _errorCard();
      case Phase.done:
        return KeyedSubtree(
          key: ValueKey(_req),
          child: ResultView(data: _result!, onRetry: () => _check(_lastText)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _phase == Phase.loading;
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const _Header(),
              const SizedBox(height: 22),
              GlassCard(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Column(
                  children: [
                    TextField(
                      controller: _ctrl,
                      minLines: 2,
                      maxLines: 5,
                      style: const TextStyle(
                        color: C.textHi,
                        fontSize: 16,
                        height: 1.4,
                      ),
                      cursorColor: C.accent,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Paste a forward or type a claim\u2026',
                        hintStyle: TextStyle(color: C.textLo),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _ctrl,
                          builder: (_, v, _) => TextButton.icon(
                            onPressed: () async {
                              if (v.text.isNotEmpty) {
                                _ctrl.clear();
                              } else {
                                final d = await Clipboard.getData('text/plain');
                                if (d?.text != null) _ctrl.text = d!.text!;
                              }
                            },
                            icon: Icon(
                              v.text.isNotEmpty
                                  ? Icons.close_rounded
                                  : Icons.content_paste_rounded,
                              size: 18,
                              color: C.textLo,
                            ),
                            label: Text(
                              v.text.isNotEmpty ? 'Clear' : 'Paste',
                              style: const TextStyle(color: C.textLo),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: loading ? null : _pickAndScan,
                          icon: const Icon(
                            Icons.image_search_rounded,
                            size: 18,
                            color: C.textLo,
                          ),
                          label: const Text(
                            'Scan',
                            style: TextStyle(color: C.textLo),
                          ),
                        ),
                        const Spacer(),
                        GradientButton(
                          label: loading ? 'Checking\u2026' : 'Check',
                          icon: Icons.search_rounded,
                          onPressed: loading ? null : () => _check(_ctrl.text),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _body(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [C.accent, C.accent2],
            ),
            boxShadow: [
              BoxShadow(
                color: C.accent2.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.verified_user_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verifi',
              style: TextStyle(
                color: C.textHi,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              'Check before you forward',
              style: TextStyle(color: C.textLo, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          blur: false,
          radius: 22,
          padding: EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.share_rounded, color: C.accent, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Share any WhatsApp forward to Verifi, or paste it above. '
                  'You get evidence and a confidence range, never a bare '
                  'true or false.',
                  style: TextStyle(
                    color: C.textHi,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(Icons.lock_outline_rounded, 'Private'),
            _Chip(Icons.balance_rounded, 'No verdicts'),
            _Chip(Icons.translate_rounded, 'Urdu & Roman Urdu'),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: C.textLo),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: C.textLo, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.label = 'Searching trusted sources\u2026'});
  final String label;

  Widget _bar(double h, {double? w}) => Container(
    height: h,
    width: w,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(h / 2),
    ),
  );

  Widget _tile() => GlassCard(
    blur: false,
    radius: 20,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(10, w: 120),
        const SizedBox(height: 12),
        _bar(14),
        const SizedBox(height: 8),
        _bar(14, w: 200),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            blur: false,
            radius: 28,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(28, w: 130),
                const SizedBox(height: 18),
                _bar(18),
                const SizedBox(height: 10),
                _bar(18, w: 220),
                const SizedBox(height: 26),
                _bar(14),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              label,
              style: const TextStyle(color: C.textLo, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          _tile(),
          const SizedBox(height: 12),
          _tile(),
        ],
      ),
    );
  }
}
