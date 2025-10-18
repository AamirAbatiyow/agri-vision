// lib/services/user_prefs.dart

/// Stores the currently logged-in user's info (local session only).
class UserSession {
  static String username = '';
  static String displayName = '';

  static bool get isLoggedIn => username.isNotEmpty;

  static void login(String user) {
    username = user;
    displayName = user; // can be customized later
  }

  static void logout() {
    username = '';
    displayName = '';
  }
}

/// Optional preferences & display settings used across the app.
/// Includes unit conversions + toggles required by the dashboard.
class UserPrefs {
  // Profile-ish prefs
  static String farmType = '';
  static String region = '';
  static String soilType = '';
  static String favoriteCrop = '';

  // ---- Units / display settings ----
  // Temperature stored natively in WeatherService as Fahrenheit; convert on demand.
  static bool _useFahrenheit = true; // default to °F
  static bool _useMph = true;        // default to mph

  static bool isDarkMode = false;    // simple flag for UI; your theme can read this

  // ---- Temperature helpers ----
  static String tempUnit() => _useFahrenheit ? '°F' : '°C';

  /// Input: Fahrenheit. Output: Fahrenheit or Celsius depending on setting.
  static double convertTemp(double tempF) {
    if (_useFahrenheit) return tempF;
    return (tempF - 32.0) * (5.0 / 9.0);
  }

  static void toggleTempUnit() {
    _useFahrenheit = !_useFahrenheit;
  }

  // ---- Speed helpers ----
  static String speedUnit() => _useMph ? 'mph' : 'km/h';

  /// Input: mph. Output: mph or km/h depending on setting.
  static double convertSpeed(double mph) {
    if (_useMph) return mph;
    return mph * 1.60934;
  }

  static void toggleSpeedUnit() {
    _useMph = !_useMph;
  }

  // ---- Dark mode toggle (flag only; wire to ThemeMode if desired) ----
  static void toggleDarkMode() {
    isDarkMode = !isDarkMode;
  }

  // Resets profile-style fields (not units)
  static void reset() {
    farmType = '';
    region = '';
    soilType = '';
    favoriteCrop = '';
  }
}
