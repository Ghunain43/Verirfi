import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'glass.dart';
import 'speaker.dart';

String _pct(double v) => '${(v * 100).round()}%';

class _Verdict {
  const _Verdict(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

_Verdict _verdict(List<Map<String, dynamic>> ev, double hi) {
  if (hi <= 0.2 || ev.isEmpty) {
    return const _Verdict(
      'Not enough evidence',
      C.neutral,
      Icons.help_outline_rounded,
    );
  }
  double s = 0, c = 0;
  for (final e in ev) {
    final q = (e['quality'] as num?)?.toDouble() ?? 0.5;
    final st = e['stance'];
    if (st == 'supporting') s += q;
    if (st == 'contradicting') c += q;
  }
  if (s > c * 1.5) {
    return const _Verdict('Likely true', C.good, Icons.check_circle_rounded);
  }
  if (c > s * 1.5) {
    return const _Verdict('Likely false', C.bad, Icons.cancel_rounded);
  }
  return const _Verdict(
    'Mixed evidence',
    C.amber,
    Icons.compare_arrows_rounded,
  );
}

/// What the phone reads aloud for a result.
String _spokenSummary(
  Map<String, dynamic> data,
  _Verdict v,
  double lo,
  double hi,
) {
  final claim = (data['claim'] ?? '').toString();
  final answer = (data['likely_answer'] ?? '').toString();
  final buf = StringBuffer('${v.label}. ');
  if (claim.isNotEmpty) buf.write('The claim: $claim. ');
  buf.write(
    'Confidence between ${(lo * 100).round()} and ${(hi * 100).round()} percent. ',
  );
  if (answer.isNotEmpty) buf.write('$answer ');
  buf.write('This is not a verdict. Check the sources before you forward it.');
  return buf.toString();
}

class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.data, this.onRetry});
  final Map<String, dynamic> data;

  /// Called by the "Search again" button when no sources were found.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (data['checkable'] != true) {
      return _NotCheckable(reason: data['reason_unchecked']?.toString());
    }
    final lo = (data['confidence_low'] as num).toDouble();
    final hi = (data['confidence_high'] as num).toDouble();
    final evidence = ((data['evidence'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final v = _verdict(evidence, hi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: Tilt3D(
            child: GlassCard(
              radius: 28,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: v.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: v.color.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(v.icon, size: 18, color: v.color),
                        const SizedBox(width: 6),
                        Text(
                          v.label,
                          style: TextStyle(
                            color: v.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CLAIM CHECKED',
                    style: TextStyle(
                      color: C.textLo,
                      fontSize: 11.5,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\u201C${data['claim'] ?? ''}\u201D',
                    style: const TextStyle(
                      color: C.textHi,
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  RangeMeter(lo: lo, hi: hi, color: v.color),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Confidence range',
                        style: TextStyle(color: C.textLo, fontSize: 13),
                      ),
                      Text(
                        '${_pct(lo)} \u2013 ${_pct(hi)}',
                        style: TextStyle(
                          color: v.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if ((data['likely_answer'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      data['likely_answer'].toString(),
                      style: const TextStyle(
                        color: C.textLo,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _ListenButton(text: _spokenSummary(data, v, lo, hi)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const FadeSlideIn(delayMs: 120, child: _Disclaimer()),
        const SizedBox(height: 22),
        if (evidence.isEmpty)
          FadeSlideIn(delayMs: 200, child: _NoEvidence(onRetry: onRetry))
        else ...[
          FadeSlideIn(
            delayMs: 200,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'EVIDENCE \u00B7 ${evidence.length}   \u00B7   tap to open, hold to copy',
                style: const TextStyle(
                  color: C.textLo,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          for (var i = 0; i < evidence.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeSlideIn(
                delayMs: min(260 + i * 70, 700),
                child: _EvidenceTile(e: evidence[i]),
              ),
            ),
        ],
      ],
    );
  }
}

class RangeMeter extends StatelessWidget {
  const RangeMeter({
    super.key,
    required this.lo,
    required this.hi,
    required this.color,
  });
  final double lo, hi;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, t, _) => LayoutBuilder(
            builder: (_, cons) {
              final w = cons.maxWidth;
              final width = (w * (hi - lo) * t).clamp(6.0, w).toDouble();
              return SizedBox(
                height: 14,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Positioned(
                      left: w * lo,
                      width: width,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.55),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%', style: TextStyle(color: C.textLo, fontSize: 11)),
            Text('50%', style: TextStyle(color: C.textLo, fontSize: 11)),
            Text('100%', style: TextStyle(color: C.textLo, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      blur: false,
      radius: 16,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: C.textLo),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not a verdict. Weigh the sources yourself before you forward.',
              style: TextStyle(color: C.textLo, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of a bare "EVIDENCE 0" when no sources were found.
class _NoEvidence extends StatelessWidget {
  const _NoEvidence({this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: false,
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 34, color: C.textLo),
          const SizedBox(height: 10),
          const Text(
            'No sources found',
            style: TextStyle(
              color: C.textHi,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We couldn\u2019t find reliable sources for this claim. That doesn\u2019t '
            'make it true or false. Don\u2019t forward it as fact until a trusted '
            'source confirms it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.textLo, fontSize: 14, height: 1.45),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            GradientButton(
              label: 'Search again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _openSource(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (opened || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Couldn\u2019t open the link, so it was copied instead'),
        duration: Duration(seconds: 2),
      ),
    );
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.e});
  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final stance = (e['stance'] ?? '').toString();
    final color = stance == 'supporting'
        ? C.good
        : stance == 'contradicting'
        ? C.bad
        : C.neutral;
    final label = stance == 'supporting'
        ? 'Supports'
        : stance == 'contradicting'
        ? 'Contradicts'
        : 'Neutral';
    final q = ((e['quality'] as num?)?.toDouble() ?? 0.5)
        .clamp(0.0, 1.0)
        .toDouble();
    final url = (e['url'] ?? '').toString();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: url.isEmpty ? null : () => _openSource(context, url),
      onLongPress: url.isEmpty
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: url));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Source link copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
            },
      child: GlassCard(
        blur: false,
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language_rounded, size: 16, color: C.textLo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (e['publisher'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: C.textLo,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (url.isNotEmpty) ...[
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 15,
                    color: C.textLo,
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              (e['title'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: C.textHi,
                fontSize: 15.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((e['snippet'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                e['snippet'].toString(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: C.textLo,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Source quality',
                  style: TextStyle(color: C.textLo, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: q,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _pct(q),
                  style: const TextStyle(color: C.textLo, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotCheckable extends StatelessWidget {
  const _NotCheckable({this.reason});
  final String? reason;

  String get _title {
    switch (reason) {
      case 'opinion':
        return 'That\u2019s an opinion';
      case 'satire':
        return 'That looks like satire';
      case 'religious':
        return 'That\u2019s a matter of belief';
      default:
        return 'Not a checkable claim';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Tilt3D(
        child: GlassCard(
          radius: 28,
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.neutral.withValues(alpha: 0.18),
                  border: Border.all(color: C.neutral.withValues(alpha: 0.5)),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: C.textHi,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: C.textHi,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verifi doesn\u2019t judge opinions, satire or beliefs. '
                'It only checks factual claims, and shows its evidence.',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.textLo, fontSize: 14, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Listen" / "Stop" button. Uses the phone's own text-to-speech.
class _ListenButton extends StatefulWidget {
  const _ListenButton({required this.text});
  final String text;

  @override
  State<_ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends State<_ListenButton> {
  @override
  void dispose() {
    Speaker.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Speaker.instance.speaking,
      builder: (_, on, _) => TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: () {
          if (on) {
            Speaker.instance.stop();
          } else {
            Speaker.instance.speak(widget.text);
          }
        },
        icon: Icon(
          on ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
          size: 20,
          color: C.accent,
        ),
        label: Text(
          on ? 'Stop' : 'Listen',
          style: const TextStyle(color: C.accent),
        ),
      ),
    );
  }
}
