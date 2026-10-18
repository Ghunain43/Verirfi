import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'glass.dart';

/// Rumor Radar: false claims spreading now, each with the reason it is listed.
class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.radar();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      debugPrint('radar failed: $e');
      if (!mounted) return;
      setState(
        () => _error = e is ApiException && e.code == 'rate_limited'
            ? 'Too many requests. Please try again in a moment.'
            : 'Couldn\u2019t load the radar. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String url) async {
    final u = Uri.tryParse(url);
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  Widget _bar(double h, {double? w}) => Container(
    height: h,
    width: w,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(h / 2),
    ),
  );

  Widget _skeleton() => Pulse(
    child: Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GlassCard(
              blur: false,
              radius: 26,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(12, w: 140),
                  const SizedBox(height: 14),
                  _bar(16),
                  const SizedBox(height: 8),
                  _bar(16, w: 220),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _card(int rank, Map<String, dynamic> it) {
    final web = it['origin'] == 'web';
    final reports = (it['reports'] as num?)?.toInt() ?? 0;
    final why = (it['why'] as String?)?.trim();
    final url = it['source_url'] as String?;
    final publisher = (it['publisher'] as String?) ?? 'fact-check';
    final badge = web ? C.bad : C.accent;
    return FadeSlideIn(
      delayMs: 60 * (rank > 6 ? 6 : rank),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GlassCard(
          radius: 26,
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: GradientText(
                  '${rank + 1}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badge.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        web
                            ? 'Rated false by fact-checkers'
                            : 'Spreading in the community',
                        style: TextStyle(
                          color: badge,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${it['claim'] ?? ''}',
                      style: const TextStyle(
                        color: C.textHi,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WHY IT\u2019S HERE',
                            style: TextStyle(
                              color: C.textLo,
                              fontSize: 10.5,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (why != null && why.isNotEmpty)
                                ? why
                                : (web
                                      ? 'Fact-checkers rated this claim false.'
                                      : 'Checked by $reports different people on several networks, so it is spreading.'),
                            style: const TextStyle(
                              color: C.textHi,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (web && url != null && url.startsWith('http'))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InkWell(
                          onTap: () => _open(url),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Source: $publisher \u2197',
                              style: const TextStyle(
                                color: C.accent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!web)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    children: [
                      Text(
                        '$reports',
                        style: const TextStyle(
                          color: C.accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'checks',
                        style: TextStyle(color: C.textLo, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return SafeArea(
      child: RefreshIndicator(
        color: C.accent,
        backgroundColor: C.bg2,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            const PageHeader(
              title: 'Rumor',
              accent: 'Radar',
              subtitle:
                  'False claims spreading right now, and why each one is listed. Pull down to refresh.',
            ),
            const SizedBox(height: 20),
            if (_error != null)
              GlassCard(
                radius: 26,
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 36,
                      color: C.amber,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: C.textHi,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Try again',
                      icon: Icons.refresh_rounded,
                      onPressed: _loading ? null : _load,
                    ),
                  ],
                ),
              )
            else if (items == null || (_loading && items.isEmpty))
              _skeleton()
            else if (items.isEmpty)
              const GlassCard(
                radius: 26,
                padding: EdgeInsets.all(22),
                child: Text(
                  'No trending rumors right now.',
                  style: TextStyle(color: C.textLo),
                ),
              )
            else
              for (var i = 0; i < items.length; i++) _card(i, items[i]),
          ],
        ),
      ),
    );
  }
}
