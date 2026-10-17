import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'api_client.dart';
import 'result_card.dart';

void main() => runApp(const MaterialApp(home: Home()));

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _api = ApiClient();
  StreamSubscription? _sub;
  Map<String, dynamic>? _result;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared);
    ReceiveSharingIntent.instance.getInitialMedia().then(_onShared);
  }

  void _onShared(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text) {
        _check(f.path); // for text shares, path holds the text
        break;
      }
    }
  }

  Future<void> _check(String text) async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await _api.quickCheck(text);
      setState(() => _result = r);
    } catch (e) {
      debugPrint('quickCheck failed: $e');
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verifi')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _result != null
          ? ResultCard(data: _result!)
          : const Center(
              child: Text('Share a forward to Verifi from WhatsApp'),
            ),
    ),
  );
}
