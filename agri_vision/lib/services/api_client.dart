// lib/services/api_client.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  String get base {
    if (!kIsWeb && Platform.isAndroid) return 'http://10.102.96.77:8000';
    return 'http://127.0.0.1:5000';
  }

  Future<http.Response> postJson(String path, Map<String, dynamic> body) =>
      http.post(
        Uri.parse('$base$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

  Future<http.Response> getRaw(String path, [Map<String, String>? params]) =>
      http.get(Uri.parse('$base$path').replace(queryParameters: params));
}
