import 'package:flutter/material.dart';

/// Shows [SplashScreen], then fades into [next].
/// Usage in main.dart:  home: SplashGate(next: const YourHomeScreen())
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.next,
    this.duration = const Duration(milliseconds: 2800),
  });

  final Widget next;
  final Duration duration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _done
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.next)
          : const SplashScreen(key: ValueKey('splash')),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF070A16);
  static const _violet = Color(0xFF8B7BFF);
  static const _teal = Color(0xFF2DD4BF);

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Progress (0..1) of the window [a, b] of the whole animation.
  double _t(double a, double b, [Curve curve = Curves.easeOut]) {
    final v = ((_c.value - a) / (b - a)).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final glow = _t(0.0, 0.5);
          final logo = _t(0.05, 0.45, Curves.easeOutBack);
          final logoFade = _t(0.05, 0.3);
          final check = _t(0.38, 0.65, Curves.easeInOut);
          final ring = _t(0.45, 0.95);
          final title = _t(0.55, 0.82);
          final tagline = _t(0.7, 0.95);
          final footer = _t(0.8, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Background gradient
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0E1433), Color(0xFF070A16)],
                  ),
                ),
              ),
              // Violet glow top-right
              Positioned(
                top: -120,
                right: -120,
                child: Opacity(
                  opacity: glow * 0.9,
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _violet.withValues(alpha: 0.35),
                          _violet.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Teal glow bottom-left
              Positioned(
                bottom: -140,
                left: -140,
                child: Opacity(
                  opacity: glow * 0.9,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _teal.withValues(alpha: 0.28),
                          _teal.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Expanding ring
                          Opacity(
                            opacity: (1 - ring) * 0.7,
                            child: Transform.scale(
                              scale: 0.7 + ring * 0.6,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _violet.withValues(alpha: 0.8),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Shield logo
                          Opacity(
                            opacity: logoFade,
                            child: Transform.scale(
                              scale: 0.6 + logo * 0.4,
                              child: SizedBox(
                                width: 124,
                                height: 124,
                                child: CustomPaint(
                                  painter: _LogoPainter(check: check),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // App name
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, (1 - title) * 16),
                        child: ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFC9C2FF)],
                          ).createShader(rect),
                          child: const Text(
                            'Verifi',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Tagline
                    Opacity(
                      opacity: tagline,
                      child: Transform.translate(
                        offset: Offset(0, (1 - tagline) * 10),
                        child: Text(
                          'Check before you forward',
                          style: TextStyle(
                            fontSize: 16,
                            letterSpacing: 0.6,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Footer
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
                child: Opacity(
                  opacity: footer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Private by design. Nothing is stored.',
                        style: TextStyle(
                          fontSize: 12.5,
                          letterSpacing: 0.4,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.check});

  /// 0..1, how much of the tick is drawn.
  final double check;

  Path _shield(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..cubicTo(w * 0.68, h * 0.16, w * 0.82, h * 0.18, w * 0.92, h * 0.20)
      ..lineTo(w * 0.92, h * 0.50)
      ..cubicTo(w * 0.92, h * 0.74, w * 0.74, h * 0.90, w * 0.5, h * 0.98)
      ..cubicTo(w * 0.26, h * 0.90, w * 0.08, h * 0.74, w * 0.08, h * 0.50)
      ..lineTo(w * 0.08, h * 0.20)
      ..cubicTo(w * 0.18, h * 0.18, w * 0.32, h * 0.16, w * 0.5, h * 0.04)
      ..close();
  }

  Path _tick(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.45, h * 0.67)
      ..lineTo(w * 0.71, h * 0.38);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shield = _shield(size);
    final grad = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B7BFF), Color(0xFF3B82F6), Color(0xFF2DD4BF)],
    ).createShader(rect);

    // Soft glow behind the outline
    canvas.drawPath(
      shield,
      Paint()
        ..shader = grad
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Glassy fill
    canvas.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B7BFF).withValues(alpha: 0.30),
            const Color(0xFF2DD4BF).withValues(alpha: 0.08),
          ],
        ).createShader(rect),
    );
    // Outline
    canvas.drawPath(
      shield,
      Paint()
        ..shader = grad
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Tick, drawn progressively
    if (check > 0) {
      final metric = _tick(size).computeMetrics().first;
      final drawn = metric.extractPath(0, metric.length * check);
      canvas.drawPath(
        drawn,
        Paint()
          ..color = const Color(0xFF2DD4BF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        drawn,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.check != check;
}
