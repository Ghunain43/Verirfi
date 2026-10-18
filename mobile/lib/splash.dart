import 'package:flutter/material.dart';
import 'glass.dart';

/// Shows [SplashScreen], then fades into [next].
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

/// App logo (assets/icon/icon.png) fading in over a glowing dark background.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _t(double a, double b, [Curve curve = Curves.easeOut]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  Widget _orb(Color color, double size, double opacity) => Opacity(
    opacity: opacity,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0)],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg1,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final glow = _t(0.0, 0.5);
          final logo = _t(0.05, 0.5, Curves.easeOutBack);
          final logoFade = _t(0.05, 0.3);
          final ring = _t(0.4, 0.95);
          final title = _t(0.5, 0.8);
          final tagline = _t(0.65, 0.95);
          final footer = _t(0.8, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [C.bg2, C.bg1],
                  ),
                ),
              ),
              Positioned(
                top: -120,
                right: -120,
                child: _orb(C.accent2, 380, glow),
              ),
              Positioned(
                bottom: -140,
                left: -140,
                child: _orb(C.cyan, 400, glow),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: (1 - ring) * 0.7,
                            child: Transform.scale(
                              scale: 0.7 + ring * 0.6,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(44),
                                  border: Border.all(
                                    color: C.accent2.withValues(alpha: 0.8),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: logoFade,
                            child: Transform.scale(
                              scale: 0.6 + logo * 0.4,
                              child: Container(
                                width: 132,
                                height: 132,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: C.accent2.withValues(alpha: 0.55),
                                      blurRadius: 44,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: Image.asset(
                                    'assets/icon/icon.png',
                                    fit: BoxFit.cover,
                                    cacheWidth: 400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, (1 - title) * 16),
                        child: const GradientText(
                          kAppName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: tagline,
                      child: Text(
                        'Check it before you share it',
                        style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 0.4,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
