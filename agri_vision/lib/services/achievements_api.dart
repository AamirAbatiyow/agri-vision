// lib/services/achievements_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AchievementsApi {
  static Future<bool> addBadge(String username, String badge) async {
    final http.Response r = await ApiClient.I.postJson('/users/$username/achievements', {'badge': badge});
    return r.statusCode == 200;
  }

  static Future<List<String>> getBadges(String username) async {
    final http.Response r = await ApiClient.I.getRaw('/users/$username/achievements');
    if (r.statusCode != 200) return [];
    final arr = (jsonDecode(r.body) as List).map((e) => e.toString()).toList();
    return arr;
  }
}
