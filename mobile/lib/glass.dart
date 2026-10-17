import 'dart:ui';
import 'package:flutter/material.dart';

/// Design tokens.
class C {
  static const bg1 = Color(0xFF0A0F24);
  static const bg2 = Color(0xFF111A3B);
  static const bg3 = Color(0xFF1B1245);
  static const accent = Color(0xFF6C8CFF);
  static const accent2 = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const good = Color(0xFF34D399);
  static const bad = Color(0xFFF87171);
  static const amber = Color(0xFFFBBF24);
  static const neutral = Color(0xFF94A3B8);
  static const textHi = Color(0xFFF1F5F9);
  static const textLo = Color(0xFF9AA7C0);
}

/// Static gradient + soft colour orbs. No animation, so the blur layers
/// above it never have to recompute: this is what keeps scrolling fast.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [C.bg1, C.bg2, C.bg3],
            ),
          ),
        ),
        const RepaintBoundary(child: _Orbs()),
        child,
      ],
    );
  }
}

class _Orbs extends StatelessWidget {
  const _Orbs();

  Widget _orb(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: -90, left: -70, child: _orb(C.accent, 340)),
        Positioned(top: 280, right: -140, child: _orb(C.accent2, 380)),
        Positioned(bottom: -110, left: -50, child: _orb(C.cyan, 320)),
      ],
    );
  }
}

/// Frosted glass panel. Set [blur] false for cheap, list-friendly tiles.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.blur = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: blur ? 0.17 : 0.11),
            Colors.white.withValues(alpha: blur ? 0.05 : 0.04),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: inner,
              )
            : inner,
      ),
    );
  }
}

/// Touch-driven 3D tilt with perspective. Uses a Listener (not a gesture
/// detector) so it never fights with scrolling.
class Tilt3D extends StatefulWidget {
  const Tilt3D({super.key, required this.child, this.maxAngle = 0.10});
  final Widget child;
  final double maxAngle;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Animation<Offset>? _back;
  Offset _t = Offset.zero;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _t = Offset.zero;
        _back = null;
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _move(PointerEvent e) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    _c.stop();
    _back = null;
    setState(() {
      _t = Offset(
        (e.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0).toDouble(),
        (e.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0).toDouble(),
      );
    });
  }

  void _release(PointerEvent e) {
    _back = Tween<Offset>(
      begin: _t,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _move,
      onPointerMove: _move,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final t = _back?.value ?? _t;
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-t.dy * widget.maxAngle)
            ..rotateY(t.dx * widget.maxAngle);
          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: child,
          );
        },
      ),
    );
  }
}

/// Fade + slide-up entrance with optional delay.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    final total = 450 + widget.delayMs;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _a = CurvedAnimation(
      parent: _c,
      curve: Interval(widget.delayMs / total, 1.0, curve: Curves.easeOutCubic),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - _a.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Gentle looping fade, used for loading skeletons.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child});
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(16);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: const LinearGradient(colors: [C.accent, C.accent2]),
          boxShadow: [
            BoxShadow(
              color: C.accent2.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: br,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
