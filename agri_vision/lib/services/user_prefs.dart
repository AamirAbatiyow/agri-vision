// lib/services/user_prefs.dart
class UserPrefs {
  static String farmType = '';
  static String region = '';

  static bool get isOnboarded => farmType.isNotEmpty && region.isNotEmpty;

  static void setOnboarding({required String farm, required String reg}) {
    farmType = farm.trim();
    region = reg.trim();
  }

  static void reset() {
    farmType = '';
    region = '';
  }
}
