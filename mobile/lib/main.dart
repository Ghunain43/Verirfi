import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'api_client.dart';
import 'glass.dart';
import 'result_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const Home(),
    );
  }
}

enum Phase { idle, loading, done, error }

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _api = ApiClient();
  final _ctrl = TextEditingController();
  StreamSubscription? _sub;
  Phase _phase = Phase.idle;
  Map<String, dynamic>? _result;
  String _error = '';
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
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) {
      return 'The check took too long. Please try again.';
    }
    if (s.contains('SocketException') || s.contains('ClientException')) {
      return 'Can\u2019t reach the Verifi server. Check your connection.';
    }
    if (s.contains('429')) return 'Too many checks. Wait a moment and retry.';
    if (s.contains('400')) return 'That text can\u2019t be checked.';
    if (s.contains('502') || s.contains('504')) {
      return 'Our fact-checking sources are busy. Try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _check(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final id = ++_req;
    _lastText = t;
    setState(() {
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
      setState(() {
        _error = _friendly(e);
        _phase = Phase.error;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _body() {
    switch (_phase) {
      case Phase.idle:
        return const FadeSlideIn(child: _Hint());
      case Phase.loading:
        return const _Skeleton();
      case Phase.error:
        return FadeSlideIn(
          child: GlassCard(
            radius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.wifi_off_rounded, size: 36, color: C.amber),
                const SizedBox(height: 12),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: C.textHi,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: () => _check(_lastText),
                ),
              ],
            ),
          ),
        );
      case Phase.done:
        return KeyedSubtree(
          key: ValueKey(_req),
          child: ResultView(data: _result!),
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
                          builder: (_, v, __) => TextButton.icon(
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
  const _Skeleton();

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
          const Center(
            child: Text(
              'Searching trusted sources\u2026',
              style: TextStyle(color: C.textLo, fontSize: 13),
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
