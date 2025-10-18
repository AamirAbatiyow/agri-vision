// lib/services/weather_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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
  final double soilMoisture; // soil moisture 0-7cm depth (%)
  final double solarRadiation; // solar radiation (kLux approximation)
  final bool hasSoilData; // true if real soil data available
  final bool hasSolarData; // true if real solar data available

  const WeatherNow({
    required this.ts,
    required this.tempF,
    required this.feelsLikeF,
    required this.humidity,
    required this.precipProb,
    required this.windMph,
    required this.condition,
    required this.soilMoisture,
    required this.solarRadiation,
    this.hasSoilData = true,
    this.hasSolarData = true,
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

  // Current location (will be updated from device GPS)
  // Default fallback to central Iowa if location unavailable
  double latitude = 41.8780;
  double longitude = -93.0977;
  bool _useDeviceLocation = true;
  bool _locationInitialized = false;

  // Cache the latest weather data
  WeatherNow? _latestWeather;
  DateTime? _latestWeatherTime;

  // Cache hourly data for trends (past 12h + next 12h)
  List<double> _hourlyTemps = [];
  List<double> _hourlyPrecip = [];
  List<double> _hourlyHumidity = [];
  List<double> _hourlyWind = [];
  List<double> _hourlySoilMoisture = [];
  List<double> _hourlySolarRadiation = [];
  DateTime? _hourlyDataTime;

  List<WeatherDay> _cachedForecast = [];
  DateTime? _forecastTime;

  // Cache duration
  static const Duration _cacheExpiration = Duration(minutes: 15);

  /// Update the location for weather data manually (disables auto device location)
  void setLocation(double lat, double lon) {
    latitude = lat;
    longitude = lon;
    _useDeviceLocation = false;
    _locationInitialized = true;
  }

  /// Enable automatic device location fetching
  void enableDeviceLocation() {
    _useDeviceLocation = true;
    _locationInitialized = false;
  }

  /// Check if using device location (vs manual location)
  bool get isUsingDeviceLocation => _useDeviceLocation;

  /// Get current location coordinates
  Map<String, double> get currentLocation => {
    'latitude': latitude,
    'longitude': longitude,
  };

  /// Get the latest cached weather data (synchronous)
  WeatherNow? get latestWeather => _latestWeather;

  /// Get hourly trend data (past 12h + next 12h)
  Map<String, List<double>> get hourlyTrends => {
    'temperature': _hourlyTemps,
    'precipitation': _hourlyPrecip,
    'humidity': _hourlyHumidity,
    'wind': _hourlyWind,
    'soilMoisture': _hourlySoilMoisture,
    'solarRadiation': _hourlySolarRadiation,
  };

  /// Get when hourly trend data was last fetched
  DateTime? get hourlyDataTime => _hourlyDataTime;

  /// Check if any cache is expired
  bool get isCacheExpired {
    final now = DateTime.now();
    if (_latestWeatherTime != null) {
      final age = now.difference(_latestWeatherTime!);
      if (age >= _cacheExpiration) return true;
    }
    return false;
  }

  /// Manually clear all cached data (forces fresh API fetch)
  void clearCache() {
    _latestWeather = null;
    _latestWeatherTime = null;
    _hourlyTemps.clear();
    _hourlyPrecip.clear();
    _hourlyHumidity.clear();
    _hourlyWind.clear();
    _hourlySoilMoisture.clear();
    _hourlySolarRadiation.clear();
    _hourlyDataTime = null;
    _cachedForecast.clear();
    _forecastTime = null;
    debugPrint('All weather cache cleared');
  }

  /// Get device location and update coordinates
  Future<bool> _updateDeviceLocation() async {
    if (!_useDeviceLocation) return true; // Skip if manual location is set

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return false;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return false;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // Low accuracy is fine for weather
          timeLimit: Duration(seconds: 10),
        ),
      );

      latitude = position.latitude;
      longitude = position.longitude;
      _locationInitialized = true;
      debugPrint('Location updated: $latitude, $longitude');
      return true;
    } catch (e) {
      debugPrint('Error getting device location: $e');
      return false;
    }
  }

  /// Begin streaming "live" weather snapshots from Open-Meteo API.
  /// Call [stop] to halt; call [dispose] to close permanently.
  Stream<WeatherNow> start({Duration period = const Duration(minutes: 15)}) {
    _timer?.cancel();

    // Initialize location and fetch weather data
    _initializeAndFetch();

    // Then fetch periodically (update location every hour, weather every 15 min)
    int updateCount = 0;
    _timer = Timer.periodic(period, (_) {
      updateCount++;
      // Update location every 4 cycles (every hour if period is 15 minutes)
      if (updateCount % 4 == 0) {
        _initializeAndFetch();
      } else {
        _fetchAndBroadcast();
        _fetchForecast();
        _fetchHourlyTrends(); // Update trends regularly
      }
    });

    // If we have cached weather, emit it immediately
    if (_latestWeather != null) {
      Future.microtask(() {
        if (!_nowCtl.isClosed) {
          debugPrint(
            'Emitting cached weather data: ${_latestWeather!.tempF}°F',
          );
          _nowCtl.add(_latestWeather!);
        }
      });
    }

    return _nowCtl.stream;
  }

  /// Initialize location and fetch all weather data
  Future<void> _initializeAndFetch() async {
    if (!_locationInitialized) {
      await _updateDeviceLocation();
    }
    // Fetch hourly trends first so current weather can use precip probability
    await _fetchHourlyTrends();
    _fetchAndBroadcast();
    _fetchForecast();
  }

  /// Fetch current weather from Open-Meteo API and broadcast
  Future<void> _fetchAndBroadcast() async {
    // Check if cache is still valid
    if (_latestWeather != null && _latestWeatherTime != null) {
      final cacheAge = DateTime.now().difference(_latestWeatherTime!);
      if (cacheAge < _cacheExpiration) {
        debugPrint('Using cached weather data (age: ${cacheAge.inMinutes}m)');
        if (!_nowCtl.isClosed) {
          _nowCtl.add(_latestWeather!);
        }
        return;
      } else {
        debugPrint(
          'Weather cache expired (age: ${cacheAge.inMinutes}m), fetching new data',
        );
      }
    }

    try {
      debugPrint('Fetching weather for: $latitude, $longitude');
      final weather = await _fetchCurrentWeather();
      if (weather != null && !_nowCtl.isClosed) {
        _latestWeather = weather; // Cache the latest data
        _latestWeatherTime = DateTime.now();
        debugPrint(
          'Broadcasting weather: ${weather.tempF}°F, ${weather.condition}',
        );
        _nowCtl.add(weather);
      } else {
        debugPrint('Weather data is null, not broadcasting');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching weather: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Fetch current weather data from Open-Meteo API
  Future<WeatherNow?> _fetchCurrentWeather() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
        'precipitation,weather_code,wind_speed_10m,'
        'soil_moisture_0_to_7cm,shortwave_radiation'
        '&temperature_unit=fahrenheit'
        '&wind_speed_unit=mph'
        '&precipitation_unit=inch'
        '&timezone=auto',
      );

      debugPrint('Calling API: $url');
      final response = await http.get(url);
      debugPrint('API Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return null;
      }

      final responseBody = response.body;
      debugPrint(
        'API Response body: ${responseBody.substring(0, min(responseBody.length, 300))}...',
      );
      final data = json.decode(responseBody);
      final current = data['current'];

      // Debug: Check what fields are available
      debugPrint('Available fields: ${current.keys.toList()}');

      final tempF = (current['temperature_2m'] ?? 72.0).toDouble();
      final feelsLikeF = (current['apparent_temperature'] ?? tempF).toDouble();
      final humidity = (current['relative_humidity_2m'] ?? 50.0).toDouble();
      final windMph = (current['wind_speed_10m'] ?? 5.0).toDouble();
      final weatherCode = current['weather_code'] ?? 0;

      // Get precipitation probability from hourly data for current hour
      // This is more accurate than using precipitation amount
      double precipProb = 0.0;
      debugPrint('Hourly precip array length: ${_hourlyPrecip.length}');

      if (_hourlyPrecip.isNotEmpty && _hourlyPrecip.length >= 13) {
        // Current hour is approximately at index 12 (middle of 24-hour range)
        // 0-11 = past 12 hours, 12 = current hour, 13-24 = next 12 hours
        precipProb = _hourlyPrecip[12];
        debugPrint('Using hourly precip prob from index 12: $precipProb%');
      } else if (_hourlyPrecip.isNotEmpty) {
        // If we have some data but not enough, use the last available value
        precipProb = _hourlyPrecip.last;
        debugPrint('Using last available precip prob: $precipProb%');
      } else {
        // Fallback: use precipitation amount if hourly data not available
        final precipAmount = (current['precipitation'] ?? 0.0).toDouble();
        precipProb = precipAmount > 0
            ? min(precipAmount * 30 + 20, 100.0)
            : 0.0;
        debugPrint(
          'Hourly data not available, using precipitation amount fallback: $precipAmount inch → $precipProb%',
        );
      }

      // Soil moisture (m³/m³) - convert to percentage (0-100%)
      // Note: Not all locations have soil moisture data available
      final soilMoistureValue = current['soil_moisture_0_to_7cm'];
      debugPrint('Soil moisture raw value: $soilMoistureValue');

      double soilMoisture;
      bool hasSoilData = soilMoistureValue != null;

      if (soilMoistureValue != null) {
        // Typical range is 0.0 to 0.5 m³/m³, we'll scale to 0-100%
        final soilMoistureRaw = soilMoistureValue.toDouble();
        soilMoisture = (soilMoistureRaw * 200).clamp(0.0, 100.0);
      } else {
        // If soil moisture not available, use humidity as a rough proxy
        // This is just a demo fallback - real soil moisture requires sensors
        debugPrint(
          'Soil moisture not available, using humidity-based estimate',
        );
        soilMoisture = (humidity * 0.6).clamp(20.0, 80.0);
      }

      // Solar radiation (W/m²) - convert to kLux approximation
      final solarRadiationValue = current['shortwave_radiation'];
      debugPrint('Solar radiation raw value: $solarRadiationValue');

      double solarRadiation;
      bool hasSolarData = solarRadiationValue != null;

      if (solarRadiationValue != null) {
        // Rough conversion: 1 W/m² ≈ 0.0079 klux (for solar spectrum)
        // Typical full sun is ~1000 W/m² ≈ 120 klux, we'll scale for display
        final solarRadiationRaw = solarRadiationValue.toDouble();
        solarRadiation = (solarRadiationRaw * 0.065).clamp(0.0, 120.0);
      } else {
        debugPrint('Solar radiation not available, returning 0');
        solarRadiation = 0.0;
      }

      final condition = _weatherCodeToCondition(weatherCode);

      return WeatherNow(
        ts: DateTime.now(),
        tempF: tempF,
        feelsLikeF: feelsLikeF,
        humidity: humidity,
        precipProb: precipProb,
        windMph: windMph,
        condition: condition,
        soilMoisture: soilMoisture,
        solarRadiation: solarRadiation,
        hasSoilData: hasSoilData,
        hasSolarData: hasSolarData,
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

  /// Fetch hourly trend data (past 12h + next 12h)
  Future<void> _fetchHourlyTrends() async {
    // Check if cache is still valid
    if (_hourlyDataTime != null) {
      final cacheAge = DateTime.now().difference(_hourlyDataTime!);
      if (cacheAge < _cacheExpiration && _hourlyTemps.isNotEmpty) {
        debugPrint('Using cached hourly trends (age: ${cacheAge.inMinutes}m)');
        return;
      } else {
        debugPrint(
          'Hourly trends cache expired (age: ${cacheAge.inMinutes}m), fetching new data',
        );
      }
    }

    try {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 12));
      final endTime = now.add(const Duration(hours: 12));

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitude&longitude=$longitude'
        '&hourly=temperature_2m,precipitation_probability,'
        'relative_humidity_2m,wind_speed_10m,'
        'soil_moisture_0_to_7cm,shortwave_radiation'
        '&temperature_unit=fahrenheit'
        '&wind_speed_unit=mph'
        '&start_hour=${startTime.toIso8601String().substring(0, 13)}'
        '&end_hour=${endTime.toIso8601String().substring(0, 13)}'
        '&timezone=auto',
      );

      debugPrint('Fetching hourly trends: $url');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('Hourly trends API Error: ${response.statusCode}');
        return;
      }

      final data = json.decode(response.body);
      final hourly = data['hourly'];

      if (hourly == null) {
        debugPrint('No hourly data available');
        return;
      }

      // Extract temperature data
      final temps = (hourly['temperature_2m'] as List?)?.cast<num>() ?? [];
      _hourlyTemps = temps.map((t) => t.toDouble()).toList();

      // Extract precipitation probability
      final precips =
          (hourly['precipitation_probability'] as List?)?.cast<num?>() ?? [];
      _hourlyPrecip = precips.map((p) => (p ?? 0).toDouble()).toList();

      // Extract humidity
      final humidity =
          (hourly['relative_humidity_2m'] as List?)?.cast<num>() ?? [];
      _hourlyHumidity = humidity.map((h) => h.toDouble()).toList();

      // Extract wind speed
      final wind = (hourly['wind_speed_10m'] as List?)?.cast<num>() ?? [];
      _hourlyWind = wind.map((w) => w.toDouble()).toList();

      // Extract soil moisture (convert m³/m³ to %)
      final soil =
          (hourly['soil_moisture_0_to_7cm'] as List?)?.cast<num?>() ?? [];
      _hourlySoilMoisture = soil.map((s) {
        if (s == null) {
          // Use humidity-based estimate if not available
          final idx = soil.indexOf(s);
          final hum = idx < _hourlyHumidity.length
              ? _hourlyHumidity[idx]
              : 50.0;
          return (hum * 0.6).clamp(20.0, 80.0);
        }
        return (s.toDouble() * 200).clamp(0.0, 100.0);
      }).toList();

      // Extract solar radiation (convert W/m² to kLux)
      final solar =
          (hourly['shortwave_radiation'] as List?)?.cast<num?>() ?? [];
      _hourlySolarRadiation = solar
          .map(
            (s) => s == null ? 0.0 : (s.toDouble() * 0.065).clamp(0.0, 120.0),
          )
          .toList();

      _hourlyDataTime = now;
      debugPrint('Fetched ${_hourlyTemps.length} hours of trend data');
    } catch (e) {
      debugPrint('Error fetching hourly trends: $e');
    }
  }

  /// Fetch forecast data from Open-Meteo API
  Future<void> _fetchForecast() async {
    // Check if cache is still valid
    if (_forecastTime != null && _cachedForecast.isNotEmpty) {
      final cacheAge = DateTime.now().difference(_forecastTime!);
      if (cacheAge < _cacheExpiration) {
        debugPrint('Using cached forecast (age: ${cacheAge.inMinutes}m)');
        return;
      } else {
        debugPrint(
          'Forecast cache expired (age: ${cacheAge.inMinutes}m), fetching new data',
        );
      }
    }

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

      debugPrint('Fetching forecast: $url');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('Forecast API Error: ${response.statusCode}');
        return;
      }

      final data = json.decode(response.body);
      final daily = data['daily'];

      if (daily == null) {
        debugPrint('No daily forecast data available');
        return;
      }

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

      _forecastTime = DateTime.now();
      debugPrint('Cached ${_cachedForecast.length} days of forecast');
    } catch (e, stackTrace) {
      debugPrint('Error fetching forecast: $e');
      debugPrint('Stack trace: $stackTrace');
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
