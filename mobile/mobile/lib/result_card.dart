import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const ResultCard({super.key, required this.data});

  Color _stance(String s) {
    switch (s) {
      case 'supporting':
        return Colors.green;
      case 'contradicting':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data['checkable'] != true) {
      return Center(
        child: Text(
          'Not something we can fact-check (${data['reason_unchecked']}).\n'
          'Opinions, satire and beliefs are not judged.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final lo = (data['confidence_low'] as num).toDouble();
    final hi = (data['confidence_high'] as num).toDouble();
    final evidence = (data['evidence'] as List).cast<Map<String, dynamic>>();

    return ListView(
      children: [
        Text(
          data['claim'] ?? '',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(data['likely_answer'] ?? ''),
        const SizedBox(height: 12),
        Text(
          'Confidence range: ${(lo * 100).round()}% to ${(hi * 100).round()}%',
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (_, c) => Stack(
            children: [
              Container(
                height: 10,
                width: c.maxWidth,
                color: Colors.grey.shade300,
              ),
              Positioned(
                left: c.maxWidth * lo,
                child: Container(
                  height: 10,
                  width: c.maxWidth * (hi - lo),
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final e in evidence)
          Card(
            child: ListTile(
              title: Text(e['title'] ?? ''),
              subtitle: Text('${e['publisher']}\n${e['snippet'] ?? ''}'),
              isThreeLine: true,
              trailing: Chip(
                label: Text(e['stance'] ?? ''),
                backgroundColor: _stance(e['stance'] ?? '').withOpacity(0.15),
              ),
            ),
          ),
      ],
    );
  }
}
