// lib/pages/results/analysis_results_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AnalysisResultsPage extends StatefulWidget {
  const AnalysisResultsPage({super.key});

  @override
  State<AnalysisResultsPage> createState() => _AnalysisResultsPageState();
}

class _AnalysisResultsPageState extends State<AnalysisResultsPage> {
  bool _loading = false;
  String? _error;
  List<dynamic> _labels = [];
  Map<String, dynamic> _ai = {};

  // Use the same backend as your Rekognition file
  static const String backendUrl = 'http://10.102.96.77:8000';

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _labels = [];
      _ai = {};
    });

    try {
      final r1 = await http.get(Uri.parse('$backendUrl/results'));
      if (r1.statusCode == 200) {
        final j = jsonDecode(r1.body) as Map<String, dynamic>;
        _labels = (j['labels'] ?? []) as List<dynamic>;
      } else {
        throw Exception('results ${r1.statusCode}');
      }

      final r2 = await http.get(Uri.parse('$backendUrl/ai_results'));
      if (r2.statusCode == 200) {
        final j = jsonDecode(r2.body);
        // normalize to a map (support your backend returning {results: {...}} or just {...})
        if (j is Map && j['results'] is Map) {
          _ai = (j['results'] as Map).map((k, v) => MapEntry(k.toString(), v));
        } else if (j is Map) {
          _ai = j.map((k, v) => MapEntry(k.toString(), v));
        } else {
          _ai = {};
        }
      } else {
        throw Exception('ai_results ${r2.statusCode}');
      }

      if (mounted) {
        setState(() => _loading = false);
        // tell caller we succeeded so Profile can bump "Analyses"
        Navigator.of(context).pop(true);
        // Re-open this page so user still sees it after notifying parent
        Future.microtask(() {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalysisResultsPage()));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to fetch results: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final disease = _ai['disease']?.toString() ?? 'N/A';
    final cause = _ai['cause']?.toString() ?? 'N/A';
    final symptoms = _ai['symptoms']?.toString() ?? 'N/A';

    final rawTreat = _ai['treatment'];
    final List<String> treatments = [];
    if (rawTreat is List) {
      treatments.addAll(rawTreat.map((e) => e.toString()));
    } else if (rawTreat is String) {
      treatments.add(rawTreat);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBox(msg: _error!)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI Diagnosis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 8),
                            _KV('Disease', disease),
                            _KV('Cause', cause),
                            _KV('Symptoms', symptoms),
                            const SizedBox(height: 10),
                            const Text('Top Treatments', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            if (treatments.isEmpty)
                              Text('No treatments available', style: TextStyle(color: scheme.onSurfaceVariant))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: treatments.map((t) => _Chip(text: t)).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Standard Labels', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 8),
                            if (_labels.isEmpty)
                              Text('No labels detected with confidence > 70%',
                                  style: TextStyle(color: scheme.onSurfaceVariant)),
                            for (int i = 0; i < _labels.length; i++)
                              _LabelRow(index: i + 1, data: _labels[i]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  const _KV(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$k:', style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(v.isEmpty ? '—' : v, style: TextStyle(color: scheme.onSurface))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final int index;
  final dynamic data;
  const _LabelRow({required this.index, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (data is Map && data['name'] != null) ? data['name'].toString() : 'Label $index';
    final conf = (data is Map && data['confidence'] != null)
        ? double.tryParse(data['confidence'].toString()) ?? 0
        : 0.0;
    final pct = (conf.clamp(0, 100)) / 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primary,
            child: Text('$index', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text('${conf.toStringAsFixed(0)}%'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(msg, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
