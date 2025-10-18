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
  bool _hasSuccessfullyLoaded = false;

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
      // Fetch standard Rekognition labels
      final r1 = await http.get(Uri.parse('$backendUrl/results'));
      if (r1.statusCode == 200) {
        final j = jsonDecode(r1.body) as Map<String, dynamic>;
        _labels = (j['labels'] ?? []) as List<dynamic>;
      } else {
        throw Exception('Standard labels unavailable (${r1.statusCode})');
      }

      // Fetch AI-powered disease analysis
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
        throw Exception('AI analysis unavailable (${r2.statusCode})');
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _hasSuccessfullyLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to fetch results: $e\n\nMake sure the backend server is running on $backendUrl';
        });
      }
    }
  }

  // Called when user manually refreshes
  Future<void> _refresh() async {
    await _fetchAll();
    if (_hasSuccessfullyLoaded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Results refreshed!'),
          duration: Duration(seconds: 2),
        ),
      );
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
            tooltip: 'Refresh Analysis',
            icon: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Gradient background matching camera page
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surface, scheme.surfaceContainerLow],
          ),
        ),
        child: _loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading analysis results...',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
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
                        const Text(
                          'AI Diagnosis',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _KV('Disease', disease),
                        _KV('Cause', cause),
                        _KV('Symptoms', symptoms),
                        const SizedBox(height: 10),
                        const Text(
                          'Top Treatments',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        if (treatments.isEmpty)
                          Text(
                            'No treatments available',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: treatments
                                .map((t) => _Chip(text: t))
                                .toList(),
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
                        const Text(
                          'Standard Labels',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_labels.isEmpty)
                          Text(
                            'No labels detected with confidence > 70%',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        for (int i = 0; i < _labels.length; i++)
                          _LabelRow(index: i + 1, data: _labels[i]),
                      ],
                    ),
                  ),
                ),
                  ],
                ),
      ),
    );
  }
}

class _Card extends StatefulWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          // modern gradient card
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.surface, scheme.surfaceContainerLow],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.child,
      ),
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
          SizedBox(
            width: 120,
            child: Text(
              '$k:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '—' : v,
              style: TextStyle(color: scheme.onSurface),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        // modern chip with gradient
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withOpacity(0.6),
            scheme.secondaryContainer.withOpacity(0.4),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: scheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatefulWidget {
  final int index;
  final dynamic data;
  const _LabelRow({required this.index, required this.data});

  @override
  State<_LabelRow> createState() => _LabelRowState();
}

class _LabelRowState extends State<_LabelRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (widget.data is Map && widget.data['name'] != null)
        ? widget.data['name'].toString()
        : 'Label ${widget.index}';
    final conf = (widget.data is Map && widget.data['confidence'] != null)
        ? double.tryParse(widget.data['confidence'].toString()) ?? 0
        : 0.0;
    final pct = (conf.clamp(0, 100)) / 100.0;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // modern badge with gradient
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${widget.index}',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // animated progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: pct * _progressAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      scheme.primary,
                                      scheme.primaryContainer,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      scheme.secondaryContainer.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  '${conf.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox({required this.msg});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withOpacity(0.3),
            border: Border.all(color: scheme.error.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
