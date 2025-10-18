// lib/services/sensor_service.dart
import 'dart:async';
import 'dart:math';

/// Point-in-time snapshot of field/environment readings.
class SensorSnapshot {
  final DateTime ts;
  final double temperatureF; // °F
  final double precipitation; // %
  final double soilMoisture; // %
  final double humidity; // %
  final double windMph; // mph
  final double sunlight; // kLux (simulated)

  const SensorSnapshot({
    required this.ts,
    required this.temperatureF,
    required this.precipitation,
    required this.soilMoisture,
    required this.humidity,
    required this.windMph,
    required this.sunlight,
  });
}

/// In-memory demo sensor stream (no hardware/APIs needed).
/// Replace internals later with real IoT/HTTP/WebSocket and keep the same API.
class SensorService {
  SensorService._();
  static final SensorService I = SensorService._();

  final _rng = Random();
  final _controller = StreamController<SensorSnapshot>.broadcast();
  Timer? _timer;

  // rolling state so values “wiggle” realistically
  double _t = 72; // temp
  double _p = 10; // precip %
  double _m = 60; // soil moisture %
  double _h = 55; // humidity %
  double _w = 7; // wind mph
  double _s = 18; // sunlight kLux

  /// Start emitting snapshots every [period].
  /// Calling start() multiple times restarts the stream.
  Stream<SensorSnapshot> start({Duration period = const Duration(seconds: 2)}) {
    _timer?.cancel();

    // Emit initial snapshot immediately
    _controller.add(
      SensorSnapshot(
        ts: DateTime.now(),
        temperatureF: _t,
        precipitation: _p,
        soilMoisture: _m,
        humidity: _h,
        windMph: _w,
        sunlight: _s,
      ),
    );

    _timer = Timer.periodic(period, (_) {
      // Gentle noise + simple diurnal/weather heuristics
      _t = _clamp(_t + _noise(1.2), 58, 90);
      _p = _clamp(_p + _noise(3) + (_isEvening ? 1.2 : -0.6), 0, 100);
      _m = _clamp(_m + (_p > 40 ? 1.0 : -0.8) + _noise(1.5), 20, 95);
      _h = _clamp(_h + _noise(2.0) + (_isEvening ? 0.6 : -0.3), 25, 95);
      _w = _clamp(_w + _noise(1.5), 0, 22);
      _s = _clamp(_s + _noise(2.5) + (_isDaytime ? 1.0 : -1.5), 0, 65);

      _controller.add(
        SensorSnapshot(
          ts: DateTime.now(),
          temperatureF: _t,
          precipitation: _p,
          soilMoisture: _m,
          humidity: _h,
          windMph: _w,
          sunlight: _s,
        ),
      );
    });
    return _controller.stream;
  }

  /// Stop emitting but keep listeners. Call [dispose] to close permanently.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Close the stream controller.
  void dispose() {
    stop();
    _controller.close();
  }

  // -------- helpers --------
  bool get _isDaytime {
    final h = DateTime.now().hour;
    return h >= 8 && h <= 18;
  }

  bool get _isEvening {
    final h = DateTime.now().hour;
    return h >= 17 && h <= 22;
  }

  double _noise(double scale) => (_rng.nextDouble() - 0.5) * 2 * scale;
  double _clamp(double v, double lo, double hi) => v.clamp(lo, hi).toDouble();
}
