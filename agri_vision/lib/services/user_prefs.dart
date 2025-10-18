// lib/services/user_prefs.dart
class UserPrefs {
  static String farmType = '';
  static String region = '';

  // Unit preferences
  static bool useCelsius = false; // false = Fahrenheit, true = Celsius
  static bool useKph = false; // false = mph, true = kph

  static bool get isOnboarded => farmType.isNotEmpty && region.isNotEmpty;

  static void setOnboarding({required String farm, required String reg}) {
    farmType = farm.trim();
    region = reg.trim();
  }

  static void reset() {
    farmType = '';
    region = '';
  }

  // Unit conversion helpers
  static double convertTemp(double fahrenheit) {
    return useCelsius ? (fahrenheit - 32) * 5 / 9 : fahrenheit;
  }

  static String tempUnit() => useCelsius ? '°C' : '°F';

  static double convertSpeed(double mph) {
    return useKph ? mph * 1.60934 : mph;
  }

  static String speedUnit() => useKph ? 'kph' : 'mph';

  static void toggleTempUnit() {
    useCelsius = !useCelsius;
  }

  static void toggleSpeedUnit() {
    useKph = !useKph;
  }
}
