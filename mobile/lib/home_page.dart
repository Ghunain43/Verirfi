import 'dart:math';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'glass.dart';

/// Landing tab: floating logo, headline, two actions and three feature cards over moving particles.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onCheck, required this.onRadar});
  final VoidCallback onCheck;
  final VoidCallback onRadar;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ptr = ValueNotifier<Offset?>(null);

  static const _features = [
    (
      'Paste anything',
      'A forward, a headline or a screenshot. We pull out the claim that can actually be checked.',
    ),
    (
      'Sources, not opinions',
      'Every answer shows the evidence behind it and a confidence range. Opinions and jokes are left alone.',
    ),
    (
      'Rumor Radar',
      'See which false claims are spreading right now, and why each one is on the list.',
    ),
  ];

  @override
  void dispose() {
    _ptr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _ptr.value = e.localPosition,
      onPointerMove: (e) => _ptr.value = e.localPosition,
      onPointerUp: (_) => _ptr.value = null,
      onPointerCancel: (_) => _ptr.value = null,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(child: ParticleField(pointer: _ptr)),
          ),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 120),
              children: [
                FadeSlideIn(
                  child: Column(
                    children: [
                      const _FloatingLogo(),
                      const SizedBox(height: 26),
                      const Text(
                        'Check it before',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: C.textHi,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const GradientText(
                        'you share it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '$kAppName weighs a claim against real sources in seconds and shows you the evidence. Nothing you paste is saved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: C.textLo,
                          fontSize: 15.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          GradientButton(
                            label: 'Check a claim',
                            icon: Icons.search_rounded,
                            onPressed: widget.onCheck,
                          ),
                          _GhostButton(
                            label: 'Rumor Radar',
                            icon: Icons.radar,
                            onTap: widget.onRadar,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                for (var i = 0; i < _features.length; i++)
                  FadeSlideIn(
                    delayMs: 150 * (i + 1),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Tilt3D(
                        child: GlassCard(
                          radius: 26,
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GradientText(
                                  '0${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _features[i].$1,
                                  style: const TextStyle(
                                    color: C.textHi,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _features[i].$2,
                                  style: const TextStyle(
                                    color: C.textLo,
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(16);
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: br,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: C.textHi),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: C.textHi,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo();

  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -9 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: Container(
        width: 118,
        height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: C.accent2.withValues(alpha: 0.5), blurRadius: 46),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Image.asset(
            'assets/icon/icon.png',
            fit: BoxFit.cover,
            cacheWidth: 400,
          ),
        ),
      ),
    );
  }
}

class _Pt {
  _Pt(this.x, this.y, this.vx, this.vy, this.z);
  double x, y, vx, vy;
  final double z;
}

/// Drifting particles with depth that shift with, and move away from, the finger.
class ParticleField extends StatefulWidget {
  const ParticleField({super.key, required this.pointer});
  final ValueListenable<Offset?> pointer;

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  final _rnd = Random(7);
  late final List<_Pt> _pts = List.generate(
    38,
    (_) => _Pt(
      _rnd.nextDouble(),
      _rnd.nextDouble(),
      (_rnd.nextDouble() - 0.5) * 0.0007,
      (_rnd.nextDouble() - 0.5) * 0.0007,
      _rnd.nextDouble() * 0.9 + 0.1,
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _FieldPainter(_pts, widget.pointer, _c),
    );
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.pts, this.pointer, Listenable repaint)
    : super(repaint: repaint);
  final List<_Pt> pts;
  final ValueListenable<Offset?> pointer;

  Color _hue(double x) =>
      HSLColor.fromAHSL(1, 190 + x * 85, 0.9, 0.7).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ptr = pointer.value;
    final shift = ptr == null
        ? Offset.zero
        : Offset(ptr.dx / size.width - 0.5, ptr.dy / size.height - 0.5);
    final pos = <Offset>[];
    for (final p in pts) {
      p.x += p.vx * (0.6 + p.z);
      p.y += p.vy * (0.6 + p.z);
      if (p.x < -0.02) p.x = 1.02;
      if (p.x > 1.02) p.x = -0.02;
      if (p.y < -0.02) p.y = 1.02;
      if (p.y > 1.02) p.y = -0.02;
      var o = Offset(p.x * size.width, p.y * size.height);
      if (ptr != null) {
        final d = (o - ptr).distance;
        if (d < 120 && d > 0) o += (o - ptr) / d * (120 - d) * 0.35 * p.z;
      }
      pos.add(o - Offset(shift.dx * 36 * p.z, shift.dy * 36 * p.z));
    }
    final line = Paint()..strokeWidth = 1;
    for (var i = 0; i < pos.length; i++) {
      for (var j = i + 1; j < pos.length; j++) {
        final d = (pos[i] - pos[j]).distance;
        if (d < 110) {
          line.color = _hue(pts[i].x).withValues(alpha: (1 - d / 110) * 0.2);
          canvas.drawLine(pos[i], pos[j], line);
        }
      }
    }
    for (var i = 0; i < pos.length; i++) {
      final c = _hue(pts[i].x);
      canvas.drawCircle(
        pos[i],
        2 + pts[i].z * 5,
        Paint()..color = c.withValues(alpha: 0.12),
      );
      canvas.drawCircle(
        pos[i],
        0.7 + pts[i].z * 1.6,
        Paint()..color = c.withValues(alpha: 0.4 + pts[i].z * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) => false;
}
