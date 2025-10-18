// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/sensor_service.dart';
import '../../services/weather_service.dart';
import '../../services/activity_service.dart';

/// --- Dashboard page with metric cards + tiny charts ---

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final Stream<SensorSnapshot> _sensor$;
  late final Stream<WeatherNow> _weather$;
  List<WeatherDay> _forecast = [];

  // Get hourly trends from weather service (past 12h + next 12h)
  List<double> get tempHistory =>
      WeatherService.I.hourlyTrends['temperature'] ?? [];
  List<double> get precipHistory =>
      WeatherService.I.hourlyTrends['precipitation'] ?? [];
  List<double> get moistHistory =>
      WeatherService.I.hourlyTrends['soilMoisture'] ?? [];
  List<double> get humidHistory =>
      WeatherService.I.hourlyTrends['humidity'] ?? [];
  List<double> get windHistory => WeatherService.I.hourlyTrends['wind'] ?? [];
  List<double> get sunHistory =>
      WeatherService.I.hourlyTrends['solarRadiation'] ?? [];

  @override
  void initState() {
    super.initState();
    _sensor$ = SensorService.I.start();
    _weather$ = WeatherService.I.start();
    _loadForecast();
    ActivityService.I.onDashboardViewed();
  }

  Future<void> _loadForecast() async {
    // Wait a moment for the initial forecast fetch to complete
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _forecast = WeatherService.I.forecast();
        debugPrint('Dashboard loaded ${_forecast.length} forecast days');
      });
    }

    // Periodically refresh forecast every minute to pick up updates
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        _loadForecast();
      }
    });
  }

  @override
  void dispose() {
    SensorService.I.stop();
    WeatherService.I.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AgriVision Dashboard')),
      body: StreamBuilder<SensorSnapshot>(
        stream: _sensor$,
        builder: (context, sensorSnap) {
          final scheme = Theme.of(context).colorScheme;

          if (!sensorSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Sensor data is still used for activity tracking
          ActivityService.I.onSensorTick();

          return StreamBuilder<WeatherNow>(
            stream: _weather$,
            builder: (context, weatherSnap) {
              // Use stream data if available, otherwise fallback to cached data
              final weather =
                  weatherSnap.data ?? WeatherService.I.latestWeather;

              // Debug: Log weather status
              if (weatherSnap.hasError) {
                debugPrint('Weather error: ${weatherSnap.error}');
              }
              if (weather != null) {
                debugPrint('Weather data received: ${weather.tempF}°F');
              } else {
                debugPrint(
                  'No weather data yet (stream: ${weatherSnap.hasData}, cached: ${WeatherService.I.latestWeather != null})',
                );
              }

              // Hourly trends are now managed by WeatherService
              // No need to manually push data - just use the getter

              return CustomScrollView(
                slivers: [
                  // --- Current Weather (from WeatherService) ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _WeatherNowCard(now: weather),
                    ),
                  ),

                  // --- Metric grid (from SensorService + Weather) ---
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    sliver: SliverGrid.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 800
                          ? 3
                          : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        MetricCard(
                          title: 'Temperature',
                          value: weather == null
                              ? 'Loading...'
                              : '${weather.tempF.toStringAsFixed(1)}°F',
                          subtitle: weather == null
                              ? 'Fetching weather data'
                              : _trendText(tempHistory),
                          icon: FontAwesomeIcons.temperatureHalf,
                          color: scheme.primaryContainer,
                          sparkline: tempHistory,
                          minMax: const MinMax(50, 100),
                          showNowMarker: true,
                        ),
                        MetricCard(
                          title: 'Precipitation',
                          value: weather == null
                              ? 'Loading...'
                              : '${weather.precipProb.toStringAsFixed(0)}%',
                          subtitle: weather == null
                              ? 'Fetching weather data'
                              : _trendText(precipHistory),
                          icon: FontAwesomeIcons.cloudRain,
                          color: scheme.secondaryContainer,
                          sparkline: precipHistory,
                          minMax: const MinMax(0, 100),
                          showNowMarker: true,
                        ),
                        MetricCard(
                          title: 'Soil Moisture',
                          value: weather == null
                              ? 'Loading...'
                              : '${weather.soilMoisture.toStringAsFixed(0)}%',
                          subtitle: weather == null
                              ? 'Fetching weather data'
                              : !weather.hasSoilData
                              ? 'Estimated (real sensors needed)'
                              : weather.soilMoisture < 35
                              ? 'Dry • Auto-watering recommended'
                              : weather.soilMoisture > 75
                              ? 'Wet • Watering paused'
                              : 'Healthy range',
                          icon: FontAwesomeIcons.droplet,
                          color: scheme.tertiaryContainer,
                          sparkline: moistHistory,
                          minMax: const MinMax(0, 100),
                          showNowMarker: true,
                        ),
                        MetricCard(
                          title: 'Humidity',
                          value: weather == null
                              ? 'Loading...'
                              : '${weather.humidity.toStringAsFixed(0)}%',
                          subtitle: weather == null
                              ? 'Fetching weather data'
                              : _trendText(humidHistory),
                          icon: FontAwesomeIcons.water,
                          color: scheme.surfaceContainerHighest,
                          sparkline: humidHistory,
                          minMax: const MinMax(0, 100),
                          showNowMarker: true,
                        ),
                        MetricCard(
                          title: 'Wind',
                          value: weather == null
                              ? 'Loading...'
                              : '${weather.windMph.toStringAsFixed(1)} mph',
                          subtitle: weather == null
                              ? 'Fetching weather data'
                              : weather.windMph > 15
                              ? 'Breezy • Secure covers'
                              : 'Calm',
                          icon: FontAwesomeIcons.wind,
                          color: scheme.surfaceContainerHigh,
                          sparkline: windHistory,
                          minMax: const MinMax(0, 25),
                          showNowMarker: true,
                        ),
                        MetricCard(
                          title: 'Sunlight',
                          value: weather == null
                              ? 'Loading...'
                              : '${weather.solarRadiation.toStringAsFixed(0)} kLux',
                          subtitle: weather == null
                              ? 'Fetching weather data'
                              : !weather.hasSolarData
                              ? 'Data unavailable'
                              : weather.solarRadiation < 8
                              ? 'Low light'
                              : 'Good exposure',
                          icon: FontAwesomeIcons.sun,
                          color: scheme.surfaceContainerLow,
                          sparkline: sunHistory,
                          minMax: const MinMax(0, 120),
                          showNowMarker: true,
                        ),
                      ],
                    ),
                  ),

                  // --- Trends ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Trends',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TrendCard(
                            title: 'Temperature (12h past ← now → 12h future)',
                            series: tempHistory,
                            minMax: const MinMax(40, 100),
                            showNowMarker: true,
                          ),
                          const SizedBox(height: 12),
                          TrendCard(
                            title:
                                'Soil Moisture (12h past ← now → 12h future)',
                            series: moistHistory,
                            minMax: const MinMax(0, 100),
                            showNowMarker: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- 5-day Forecast row (from WeatherService) ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _ForecastRow(days: _forecast),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _trendText(List<double> h) {
    if (h.length < 2) return '—';
    final diff = h.last - h.first;
    if (diff.abs() < 0.5) return 'Stable';
    return diff > 0 ? 'Rising' : 'Falling';
  }
}

/// --- Weather: Current conditions card ---

class _WeatherNowCard extends StatelessWidget {
  final WeatherNow? now;
  const _WeatherNowCard({required this.now});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final emoji = now == null ? '⛅' : WeatherView.emojiFor(now!.condition);
    final title = now?.condition ?? 'Loading…';
    final temp = now == null ? '—' : '${now!.tempF.toStringAsFixed(0)}°F';
    final feels = now == null ? '—' : '${now!.feelsLikeF.toStringAsFixed(0)}°F';
    final humid = now == null ? '—' : '${now!.humidity.toStringAsFixed(0)}%';
    final precip = now == null ? '—' : '${now!.precipProb.toStringAsFixed(0)}%';
    final wind = now == null ? '—' : '${now!.windMph.toStringAsFixed(0)} mph';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 14,
                  runSpacing: -4,
                  children: [
                    _ChipText(
                      icon: FontAwesomeIcons.temperatureHalf,
                      text: 'Temp $temp',
                    ),
                    _ChipText(
                      icon: FontAwesomeIcons.fireFlameCurved,
                      text: 'Feels $feels',
                    ),
                    _ChipText(icon: FontAwesomeIcons.water, text: 'Hum $humid'),
                    _ChipText(
                      icon: FontAwesomeIcons.cloudRain,
                      text: 'Precip $precip',
                    ),
                    _ChipText(icon: FontAwesomeIcons.wind, text: 'Wind $wind'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ChipText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// --- Forecast row ---

class _ForecastRow extends StatelessWidget {
  final List<WeatherDay> days;
  const _ForecastRow({required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '5-Day Forecast',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: days.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Loading forecast...',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : Row(
                  children: days.map((d) {
                    final emoji = WeatherView.emojiFor(d.condition);
                    final label = WeatherView.shortLabel(d.day);
                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            label,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 6),
                          Text(
                            '${d.highF.toStringAsFixed(0)}° / ${d.lowF.toStringAsFixed(0)}°',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.cloudRain,
                                size: 11,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${d.precipProb.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

/// --- UI: Metric card with sparkline ---

class MinMax {
  final double min;
  final double max;
  const MinMax(this.min, this.max);
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<double> sparkline;
  final MinMax minMax;
  final bool showNowMarker;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.sparkline,
    required this.minMax,
    this.showNowMarker = false,
  });

  @override
  Widget build(BuildContext context) {
    final onContainer = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: FaIcon(icon, color: onContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Sparkline(
                  series: sparkline,
                  minMax: minMax,
                  showNowMarker: showNowMarker,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// --- Simple custom painter for lines (no external packages) ---

class Sparkline extends StatelessWidget {
  final List<double> series;
  final MinMax minMax;
  final bool showNowMarker;

  const Sparkline({
    super.key,
    required this.series,
    required this.minMax,
    this.showNowMarker = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinePainter(
        series: series,
        min: minMax.min,
        max: minMax.max,
        showNowMarker: showNowMarker,
      ),
      size: Size.infinite,
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> series;
  final double min;
  final double max;
  final bool showNowMarker;

  _LinePainter({
    required this.series,
    required this.min,
    required this.max,
    this.showNowMarker = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF2E7D32); // green accent

    if (series.length < 2) return;

    final path = Path();
    final n = series.length;
    final dx = size.width / (n - 1);

    double mapY(double v) {
      final t = ((v - min) / (max - min)).clamp(0.0, 1.0);
      return size.height - (t * size.height);
    }

    path.moveTo(0, mapY(series.first));
    for (int i = 1; i < n; i++) {
      path.lineTo(dx * i, mapY(series[i]));
    }

    final basePaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final base = Path()
      ..moveTo(0, mapY(series.first))
      ..lineTo(size.width, mapY(series.first));
    canvas.drawPath(base, basePaint);

    canvas.drawPath(path, paint);

    // Draw "now" marker line in the middle
    if (showNowMarker) {
      final nowPaint = Paint()
        ..color =
            const Color(0xFFFF6B6B) // red accent for "now"
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final nowX = size.width / 2;
      canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height), nowPaint);

      // Add a small "NOW" label at the bottom
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'NOW',
          style: TextStyle(
            color: Color(0xFFFF6B6B),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(nowX - textPainter.width / 2, size.height - textPainter.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.showNowMarker != showNowMarker;
  }
}

/// --- Trend card (bigger chart) ---

class TrendCard extends StatelessWidget {
  final String title;
  final List<double> series;
  final MinMax minMax;
  final bool showNowMarker;

  const TrendCard({
    super.key,
    required this.title,
    required this.series,
    required this.minMax,
    this.showNowMarker = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                _current(series),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Sparkline(
              series: series,
              minMax: minMax,
              showNowMarker: showNowMarker,
            ),
          ),
        ],
      ),
    );
  }

  String _current(List<double> s) =>
      s.isEmpty ? '—' : s.last.toStringAsFixed(1);
}
