import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass.dart';
import 'home_page.dart';
import 'main.dart' show CheckPage;
import 'radar_page.dart';

/// Home, Check and Radar tabs with a floating glass tab bar.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  void _go(int i) {
    if (i != _i) setState(() => _i = i);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;
    return PopScope(
      canPop: _i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: GlassBackground(
          child: Stack(
            children: [
              IndexedStack(
                index: _i,
                children: [
                  HomePage(onCheck: () => _go(1), onRadar: () => _go(2)),
                  CheckPage(onShared: () => _go(1)),
                  const RadarPage(),
                ],
              ),
              if (!keyboard)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 12 + mq.padding.bottom,
                  child: _NavBar(index: _i, onTap: _go),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.fact_check_rounded, 'Check'),
    (Icons.radar, 'Radar'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: C.bg2.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: i == index
                            ? const LinearGradient(
                                colors: [C.cyan, C.accent, C.accent2],
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _items[i].$1,
                            size: 21,
                            color: i == index ? Colors.white : C.textLo,
                          ),
                          if (i == index) ...[
                            const SizedBox(width: 6),
                            Text(
                              _items[i].$2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
