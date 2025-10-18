// lib/services/chat_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ChatMessageDto {
  final String room; // "general" or "dm"
  final String sender;
  final String text;
  final String ts;
  final List<String>? participants; // for DM only

  ChatMessageDto({required this.room, required this.sender, required this.text, required this.ts, this.participants});

  factory ChatMessageDto.fromMap(Map<String, dynamic> m) => ChatMessageDto(
        room: m['room'] ?? 'general',
        sender: m['sender'] ?? '',
        text: m['text'] ?? '',
        ts: m['ts'] ?? '',
        participants: (m['participants'] as List?)?.map((e) => e.toString()).toList(),
      );
}

class ChatApi {
  static Future<bool> postGeneral({required String sender, required String text}) async {
    final res = await ApiClient.I.postJson('/messages', {'room': 'general', 'sender': sender, 'text': text});
    return res.statusCode == 201;
  }

  static Future<bool> postDm({required String a, required String b, required String sender, required String text}) async {
    final res = await ApiClient.I.postJson('/messages', {'room': 'dm', 'a': a, 'b': b, 'sender': sender, 'text': text});
    return res.statusCode == 201;
  }

  static Future<List<ChatMessageDto>> fetchGeneral({String? afterIso, int limit = 200}) async {
    final params = <String, String>{'limit': '$limit'};
    if (afterIso != null) params['after'] = afterIso;
    final http.Response r = await ApiClient.I.getRaw('/messages/general', params);
    if (r.statusCode != 200) return [];
    final arr = jsonDecode(r.body) as List;
    return arr.map((e) => ChatMessageDto.fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<List<ChatMessageDto>> fetchDm({required String a, required String b, String? afterIso, int limit = 200}) async {
    final params = <String, String>{'a': a, 'b': b, 'limit': '$limit'};
    if (afterIso != null) params['after'] = afterIso;
    final http.Response r = await ApiClient.I.getRaw('/messages/dm', params);
    if (r.statusCode != 200) return [];
    final arr = jsonDecode(r.body) as List;
    return arr.map((e) => ChatMessageDto.fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchThreads(String username) async {
    final r = await ApiClient.I.getRaw('/messages/threads/$username');
    if (r.statusCode != 200) return [];
    final arr = jsonDecode(r.body) as List;
    return arr.cast<Map<String, dynamic>>();
  }
}
