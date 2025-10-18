// lib/services/weather_service.dart
import 'dart:async';
import 'dart:math';

/// Current conditions model.
class WeatherNow {
  final DateTime ts;
  final double tempF;       // current temp
  final double feelsLikeF;  // "feels like"
  final double humidity;    // %
  final double precipProb;  // %
  final double windMph;     // mph
  final String condition;   // e.g., 'Sunny', 'Cloudy', 'Rain'

  const WeatherNow({
    required this.ts,
    required this.tempF,
    required this.feelsLikeF,
    required this.humidity,
    required this.precipProb,
    required this.windMph,
    required this.condition,
  });
}

/// Daily forecast summary.
class WeatherDay {
  final DateTime day;
  final double highF;
  final double lowF;
  final double precipProb; // %
  final String condition;

  const WeatherDay({
    required this.day,
    required this.highF,
    required this.lowF,
    required this.precipProb,
    required this.condition,
  });
}

/// Simple, demo-friendly weather service.
/// - No HTTP; values are procedurally generated.
/// - Swap internals later with a real client while keeping the same API.
class WeatherService {
  WeatherService._();
  static final WeatherService I = WeatherService._();

  final _rng = Random();
  final _nowCtl = StreamController<WeatherNow>.broadcast();
  Timer? _timer;

  /// Begin streaming "live" weather snapshots (demo).
  /// Call [stop] to halt; call [dispose] to close permanently.
  Stream<WeatherNow> start({Duration period = const Duration(seconds: 5)}) {
    _timer?.cancel();

    // Seed base values around a mild day.
    double temp = 72;
    double humid = 55;
    double wind = 7;
    double precip = 10;

    _timer = Timer.periodic(period, (_) {
      // Gentle wiggle; slight evening cooling heuristic.
      final h = DateTime.now().hour;
      final diurnal = (h >= 18 || h <= 7) ? -0.3 : 0.2;

      temp = _clamp(temp + diurnal + _noise(1.2), 55, 95);
      humid = _clamp(humid + _noise(2.0), 25, 95);
      wind = _clamp(wind + _noise(1.5), 0, 25);
      precip = _clamp(precip + _noise(4.0) + (h >= 17 ? 1.5 : -0.8), 0, 100);

      final cond = _pickCondition(temp, humid, precip);
      final feels = _computeFeelsLike(temp, humid, wind);

      _nowCtl.add(WeatherNow(
        ts: DateTime.now(),
        tempF: temp,
        feelsLikeF: feels,
        humidity: humid,
        precipProb: precip,
        windMph: wind,
        condition: cond,
      ));
    });

    return _nowCtl.stream;
  }

  /// Stop emitting updates (stream remains open).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Close stream (irreversible).
  void dispose() {
    stop();
    _nowCtl.close();
  }

  /// Generate a 5-day forecast (mock).
  List<WeatherDay> forecast() {
    final now = DateTime.now();
    final baseHigh = 74 + _rng.nextInt(7); // 74–80
    final baseLow = 58 + _rng.nextInt(6);  // 58–63

    return List.generate(5, (i) {
      final day = now.add(Duration(days: i));
      final high = (baseHigh + _noise(3)).clamp(60, 95).toDouble();
      final low = (baseLow + _noise(3)).clamp(45, high - 2).toDouble();
      final precip = _clamp(15 + _noise(20) + (i == 2 ? 20 : 0), 0, 100);
      final cond = _pickCondition((high + low) / 2, 55 + _noise(10), precip);
      return WeatherDay(
        day: DateTime(day.year, day.month, day.day),
        highF: high,
        lowF: low,
        precipProb: precip,
        condition: cond,
      );
    });
  }

  // ----------------- Helpers -----------------

  String _pickCondition(double tempF, double humidity, double precipProb) {
    if (precipProb > 60) {
      return humidity > 70 ? 'Rain' : 'Showers';
    }
    if (humidity > 75 && tempF < 65) return 'Fog';
    if (humidity < 35 && tempF > 85) return 'Hot & Dry';
    if (humidity < 35 && tempF < 60) return 'Clear';
    if (humidity > 65 && tempF < 60) return 'Cloudy';
    return 'Partly Cloudy';
  }

  double _computeFeelsLike(double t, double h, double w) {
    // Very rough "feels like": humidity increases heat, wind cools slightly.
    return _clamp(t + (h - 50) * 0.06 - min(w, 15) * 0.1, 40, 110);
  }

  double _noise(double scale) => (_rng.nextDouble() - 0.5) * 2 * scale;
  double _clamp(double v, double lo, double hi) => v.clamp(lo, hi).toDouble();
}

/// Optional: tiny view model mappers (icons/labels can be used by UI).
class WeatherView {
  static String emojiFor(String condition) {
    switch (condition) {
      case 'Rain':
      case 'Showers':
        return '🌧️';
      case 'Fog':
        return '🌫️';
      case 'Hot & Dry':
        return '🔥';
      case 'Cloudy':
        return '☁️';
      case 'Clear':
        return '🌙';
      default:
        return '⛅';
    }
  }

  static String shortLabel(DateTime day) {
    const w = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return w[day.weekday % 7];
  }
}
