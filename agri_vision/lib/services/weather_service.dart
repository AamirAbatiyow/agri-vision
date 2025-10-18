// lib/services/weather_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Current conditions model.
class WeatherNow {
  final DateTime ts;
  final double tempF; // current temp
  final double feelsLikeF; // "feels like"
  final double humidity; // %
  final double precipProb; // %
  final double windMph; // mph
  final String condition; // e.g., 'Sunny', 'Cloudy', 'Rain'

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

/// Weather service using Open-Meteo API.
/// Provides real-time weather data and forecasts.
class WeatherService {
  WeatherService._();
  static final WeatherService I = WeatherService._();

  final _nowCtl = StreamController<WeatherNow>.broadcast();
  Timer? _timer;

  // Default location (can be configured)
  // Using coordinates for central Iowa as an example agricultural location
  double latitude = 41.8780;
  double longitude = -93.0977;

  List<WeatherDay> _cachedForecast = [];

  /// Update the location for weather data
  void setLocation(double lat, double lon) {
    latitude = lat;
    longitude = lon;
  }

  /// Begin streaming "live" weather snapshots from Open-Meteo API.
  /// Call [stop] to halt; call [dispose] to close permanently.
  Stream<WeatherNow> start({Duration period = const Duration(minutes: 5)}) {
    _timer?.cancel();

    // Fetch immediately on start (both current weather and forecast)
    _fetchAndBroadcast();
    _fetchForecast();

    // Then fetch periodically
    _timer = Timer.periodic(period, (_) {
      _fetchAndBroadcast();
      _fetchForecast();
    });

    return _nowCtl.stream;
  }

  /// Fetch current weather from Open-Meteo API and broadcast
  Future<void> _fetchAndBroadcast() async {
    try {
      final weather = await _fetchCurrentWeather();
      if (weather != null && !_nowCtl.isClosed) {
        _nowCtl.add(weather);
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
  }

  /// Fetch current weather data from Open-Meteo API
  Future<WeatherNow?> _fetchCurrentWeather() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
        'precipitation,weather_code,wind_speed_10m'
        '&temperature_unit=fahrenheit'
        '&wind_speed_unit=mph'
        '&precipitation_unit=inch'
        '&timezone=auto',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('API Error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final current = data['current'];

      final tempF = (current['temperature_2m'] ?? 72.0).toDouble();
      final feelsLikeF = (current['apparent_temperature'] ?? tempF).toDouble();
      final humidity = (current['relative_humidity_2m'] ?? 50.0).toDouble();
      final windMph = (current['wind_speed_10m'] ?? 5.0).toDouble();
      final weatherCode = current['weather_code'] ?? 0;

      // Open-Meteo doesn't provide direct precipitation probability for current
      // We'll use precipitation amount as a proxy (0 = 0%, >0 = some percentage)
      final precipAmount = (current['precipitation'] ?? 0.0).toDouble();
      final precipProb = precipAmount > 0
          ? min(precipAmount * 30 + 20, 100.0)
          : 0.0;

      final condition = _weatherCodeToCondition(weatherCode);

      return WeatherNow(
        ts: DateTime.now(),
        tempF: tempF,
        feelsLikeF: feelsLikeF,
        humidity: humidity,
        precipProb: precipProb,
        windMph: windMph,
        condition: condition,
      );
    } catch (e) {
      debugPrint('Error parsing weather data: $e');
      return null;
    }
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

  /// Fetch 5-day forecast from Open-Meteo API
  List<WeatherDay> forecast() {
    // Return cached forecast immediately, but also fetch new data
    _fetchForecast();
    return _cachedForecast;
  }

  /// Fetch forecast data from Open-Meteo API
  Future<void> _fetchForecast() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitude&longitude=$longitude'
        '&daily=temperature_2m_max,temperature_2m_min,'
        'precipitation_probability_max,weather_code'
        '&temperature_unit=fahrenheit'
        '&timezone=auto'
        '&forecast_days=5',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('Forecast API Error: ${response.statusCode}');
        return;
      }

      final data = json.decode(response.body);
      final daily = data['daily'];

      final times = (daily['time'] as List);
      final maxTemps = (daily['temperature_2m_max'] as List);
      final minTemps = (daily['temperature_2m_min'] as List);
      final precipProbs = (daily['precipitation_probability_max'] as List);
      final weatherCodes = (daily['weather_code'] as List);

      _cachedForecast = List.generate(min(5, times.length), (i) {
        return WeatherDay(
          day: DateTime.parse(times[i]),
          highF: (maxTemps[i] ?? 75.0).toDouble(),
          lowF: (minTemps[i] ?? 55.0).toDouble(),
          precipProb: (precipProbs[i] ?? 0.0).toDouble(),
          condition: _weatherCodeToCondition(weatherCodes[i] ?? 0),
        );
      });
    } catch (e) {
      debugPrint('Error fetching forecast: $e');
    }
  }

  // ----------------- Helpers -----------------

  /// Convert WMO weather code to human-readable condition
  /// Reference: https://open-meteo.com/en/docs
  String _weatherCodeToCondition(int code) {
    switch (code) {
      case 0:
        return 'Clear';
      case 1:
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Cloudy';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 66:
      case 67:
        return 'Freezing Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 77:
        return 'Snow Grains';
      case 80:
      case 81:
      case 82:
        return 'Showers';
      case 85:
      case 86:
        return 'Snow Showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with Hail';
      default:
        return 'Partly Cloudy';
    }
  }
}

/// Optional: tiny view model mappers (icons/labels can be used by UI).
class WeatherView {
  static String emojiFor(String condition) {
    switch (condition) {
      case 'Rain':
      case 'Showers':
      case 'Freezing Rain':
        return '🌧️';
      case 'Drizzle':
        return '🌦️';
      case 'Snow':
      case 'Snow Showers':
      case 'Snow Grains':
        return '❄️';
      case 'Thunderstorm':
      case 'Thunderstorm with Hail':
        return '⛈️';
      case 'Fog':
        return '🌫️';
      case 'Hot & Dry':
        return '🔥';
      case 'Cloudy':
        return '☁️';
      case 'Clear':
        // Use sun during day, moon at night
        final hour = DateTime.now().hour;
        return (hour >= 6 && hour < 20) ? '☀️' : '🌙';
      case 'Partly Cloudy':
        final hour = DateTime.now().hour;
        return (hour >= 6 && hour < 20) ? '⛅' : '🌙';
      default:
        return '⛅';
    }
  }

  static String shortLabel(DateTime day) {
    const w = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return w[day.weekday % 7];
  }
}
