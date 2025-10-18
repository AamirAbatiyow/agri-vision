// lib/pages/home/home_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // fake live-ish data for the dashboard
  final rnd = Random();
  double tempC = 24.0;
  double moisture = 52.0;
  double sunlight = 68.0;
  double precipitation = 10.0;
  double soilPh = 6.5;

  @override
  void initState() {
    super.initState();
    // quick ticker to make the dashboard feel alive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tick();
    });
  }

  void _tick() async {
    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      tempC += rnd.nextDouble() * 1.2 - 0.6;
      moisture = (moisture + rnd.nextDouble() * 4 - 2).clamp(10, 90);
      sunlight = (sunlight + rnd.nextDouble() * 6 - 3).clamp(0, 100);
      precipitation = (precipitation + rnd.nextDouble() * 3 - 1.5).clamp(0, 50);
      soilPh = (soilPh + rnd.nextDouble() * 0.1 - 0.05).clamp(5.5, 7.5);
    });
    _tick();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriVision Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatGrid(children: [
            _StatCard(
              title: 'Temperature',
              value: '${tempC.toStringAsFixed(1)}°C',
              icon: FontAwesomeIcons.temperatureHalf,
              color: scheme.primaryContainer,
            ),
            _StatCard(
              title: 'Soil Moisture',
              value: '${moisture.toStringAsFixed(0)}%',
              icon: FontAwesomeIcons.water,
              color: scheme.secondaryContainer,
            ),
            _StatCard(
              title: 'Sunlight',
              value: '${sunlight.toStringAsFixed(0)}%',
              icon: FontAwesomeIcons.solarPanel,
              color: scheme.tertiaryContainer,
            ),
            _StatCard(
              title: 'Precipitation',
              value: '${precipitation.toStringAsFixed(1)} mm',
              icon: FontAwesomeIcons.cloudRain,
              color: scheme.surfaceContainerHigh,
            ),
            _StatCard(
              title: 'Soil pH',
              value: soilPh.toStringAsFixed(2),
              icon: FontAwesomeIcons.flask,
              color: scheme.surfaceContainerHighest,
            ),
            _StatCard(
              title: 'Status',
              value: _statusText(),
              icon: FontAwesomeIcons.seedling,
              color: scheme.surfaceContainerLow,
            ),
          ]),
          const SizedBox(height: 16),
          _TipsCard(
            tips: _recommendations(),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    if (moisture < 35) return 'Dry — consider irrigation';
    if (sunlight > 85) return 'High sun — consider shading';
    if (soilPh < 6.0) return 'Acidic — add lime';
    if (soilPh > 7.2) return 'Alkaline — add sulfur';
    return 'Optimal';
  }

  List<String> _recommendations() {
    final tips = <String>[];
    if (moisture < 35) tips.add('Irrigate for ~20–30 min to reach ~55% moisture.');
    if (sunlight > 85) tips.add('Deploy shade cloth during midday hours.');
    if (precipitation < 2) tips.add('Low rainfall forecast — plan irrigation.');
    if (soilPh < 6.0) tips.add('Apply garden lime to raise pH gradually.');
    if (soilPh > 7.2) tips.add('Apply elemental sulfur to lower pH slowly.');
    if (tips.isEmpty) tips.add('Conditions look good. Maintain current schedule.');
    return tips;
  }
}

// --- UI bits ---

class _StatGrid extends StatelessWidget {
  final List<Widget> children;
  const _StatGrid({required this.children});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cols = w > 1000 ? 3 : (w > 620 ? 2 : 1);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: children,
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.surface,
            child: Icon(icon, size: 18, color: scheme.onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final List<String> tips;
  const _TipsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Automation Recommendations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
