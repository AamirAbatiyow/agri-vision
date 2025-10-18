// lib/services/chat_store.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'activity_service.dart';
import 'user_prefs.dart';

/// ---------------------------------------------------------------------------
/// Chat API (Flask + Mongo)
/// Endpoints assumed:
///   GET  /messages/general?after=<iso>&limit=<n>
///   POST /messages/general              { sender, text }
///   GET  /messages/dm?a=<userA>&b=<userB>&after=<iso>&limit=<n>
///   POST /messages/dm                   { a, b, sender, text }
///   GET  /messages/threads/<username>   -> [{peer, lastTs}]
/// Adjust baseUrl if needed.
/// ---------------------------------------------------------------------------
class ChatApi {
  // Android emulator -> host machine: use 10.0.2.2
  static const String baseUrl = 'http://10.0.2.2:5000';

  // ------- DTOs -------
  static GeneralDto _dtoFromGeneralJson(Map<String, dynamic> j) => GeneralDto(
        sender: (j['sender'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        ts: (j['ts'] ?? '').toString(),
      );

  static DmDto _dtoFromDmJson(Map<String, dynamic> j) => DmDto(
        sender: (j['sender'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        ts: (j['ts'] ?? '').toString(),
      );

  // ------- General -------
  static Future<List<GeneralDto>> fetchGeneral({String? afterIso, int limit = 200}) async {
    final q = <String>[];
    if (afterIso != null && afterIso.isNotEmpty) q.add('after=$afterIso');
    q.add('limit=$limit');
    final uri = Uri.parse('$baseUrl/messages/general?${q.join('&')}');
    try {
      final r = await http.get(uri);
      if (r.statusCode != 200) return [];
      final list = jsonDecode(r.body) as List;
      return list.map((e) => _dtoFromGeneralJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> postGeneral({required String sender, required String text}) async {
    final uri = Uri.parse('$baseUrl/messages/general');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sender': sender, 'text': text}),
    );
  }

  // ------- DMs -------
  static Future<List<DmDto>> fetchDm({
    required String a,
    required String b,
    String? afterIso,
    int limit = 200,
  }) async {
    final q = <String>['a=$a', 'b=$b', 'limit=$limit'];
    if (afterIso != null && afterIso.isNotEmpty) q.add('after=$afterIso');
    final uri = Uri.parse('$baseUrl/messages/dm?${q.join('&')}');
    try {
      final r = await http.get(uri);
      if (r.statusCode != 200) return [];
      final list = jsonDecode(r.body) as List;
      return list.map((e) => _dtoFromDmJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> postDm({
    required String a,
    required String b,
    required String sender,
    required String text,
  }) async {
    final uri = Uri.parse('$baseUrl/messages/dm');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'a': a, 'b': b, 'sender': sender, 'text': text}),
    );
  }

  // ------- Threads (DM peers) -------
  static Future<List<Map<String, dynamic>>> fetchThreads(String username) async {
    final uri = Uri.parse('$baseUrl/messages/threads/$username');
    try {
      final r = await http.get(uri);
      if (r.statusCode != 200) return [];
      final list = jsonDecode(r.body) as List;
      return List<Map<String, dynamic>>.from(list);
    } catch (_) {
      return [];
    }
  }
}

class GeneralDto {
  final String sender;
  final String text;
  final String ts; // ISO
  GeneralDto({required this.sender, required this.text, required this.ts});
}

class DmDto {
  final String sender;
  final String text;
  final String ts; // ISO
  DmDto({required this.sender, required this.text, required this.ts});
}

/// ---------------------------------------------------------------------------
/// ChatMessage model for UI (used by your pages):
/// fields used in UI: senderUser, text, ts, mine, pending
/// ---------------------------------------------------------------------------
class ChatMessage {
  final String id;            // "iso-sender" or local temp id
  final String senderUser;
  final String text;
  final DateTime ts;
  final bool mine;
  final bool pending;

  ChatMessage({
    required this.id,
    required this.senderUser,
    required this.text,
    required this.ts,
    required this.mine,
    this.pending = false,
  });

  ChatMessage copyWith({
    String? id,
    String? senderUser,
    String? text,
    DateTime? ts,
    bool? mine,
    bool? pending,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderUser: senderUser ?? this.senderUser,
      text: text ?? this.text,
      ts: ts ?? this.ts,
      mine: mine ?? this.mine,
      pending: pending ?? this.pending,
    );
  }
}

/// ---------------------------------------------------------------------------
/// ChatStore singleton expected by your UI pages:
/// - ChatStore.I
/// - general : List<ChatMessage>
/// - startGeneralPolling(), stopGeneralPolling(), postGeneral(text)
/// - dmThread(peer), dmPeersByRecency(), startDmPolling(peer), stopDmPolling(peer), postDm(peer, text)
/// This also de-dupes optimistic sends when server echoes back (pending→server).
/// ---------------------------------------------------------------------------
class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore I = ChatStore._();

  // -------- General --------
  final List<ChatMessage> general = [];
  final Set<String> _seenGeneral = {};
  String? _lastGeneralIso;
  Timer? _generalTimer;

  // -------- DMs --------
  final Map<String, List<ChatMessage>> _dm = {};
  final Map<String, Set<String>> _seenDm = {};
  final Map<String, String?> _lastDmIso = {};
  final Map<String, Timer> _dmTimers = {};

  // ===== GENERAL =====

  void startGeneralPolling({Duration every = const Duration(seconds: 2)}) {
    _generalTimer?.cancel();
    _pollGeneral(); // immediate
    _generalTimer = Timer.periodic(every, (_) => _pollGeneral());
  }

  void stopGeneralPolling() {
    _generalTimer?.cancel();
    _generalTimer = null;
  }

  Future<void> _pollGeneral() async {
    final rows = await ChatApi.fetchGeneral(afterIso: _lastGeneralIso, limit: 200);
    if (rows.isEmpty) return;

    bool changed = false;

    for (final dto in rows) {
      final serverId = '${dto.ts}-${dto.sender}';
      if (_seenGeneral.contains(serverId)) {
        _lastGeneralIso = dto.ts;
        continue;
      }

      // Try to match a pending optimistic local message (same sender + text)
      final idx = general.indexWhere((m) => m.pending && m.senderUser == dto.sender && m.text == dto.text);
      if (idx >= 0) {
        general[idx] = general[idx].copyWith(
          id: serverId,
          ts: DateTime.tryParse(dto.ts)?.toLocal() ?? general[idx].ts,
          pending: false,
        );
      } else {
        general.add(ChatMessage(
          id: serverId,
          senderUser: dto.sender,
          text: dto.text,
          ts: DateTime.tryParse(dto.ts)?.toLocal() ?? DateTime.now(),
          mine: dto.sender == UserSession.username,
          pending: false,
        ));
      }

      _seenGeneral.add(serverId);
      _lastGeneralIso = dto.ts;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  Future<void> postGeneral(String text) async {
    final me = UserSession.username;
    if (me.isEmpty || text.trim().isEmpty) return;

    // optimistic append
    final now = DateTime.now();
    final tempId = 'pending-${now.microsecondsSinceEpoch}';
    general.add(ChatMessage(
      id: tempId,
      senderUser: me,
      text: text,
      ts: now,
      mine: true,
      pending: true,
    ));
    notifyListeners();

    // server post (poll will reconcile)
    try {
      await ChatApi.postGeneral(sender: me, text: text);
      ActivityService.I.onGeneralSent(); // instant counters & lastActive
    } catch (_) {
      // keep optimistic message; in demo/offline it's fine
    }
  }

  // ===== DMs =====

  List<ChatMessage> dmThread(String peer) => _dm.putIfAbsent(peer, () => <ChatMessage>[]);
  Set<String> _dmSeenSet(String peer) => _seenDm.putIfAbsent(peer, () => <String>{});

  List<String> dmPeersByRecency() {
    final peers = _dm.keys.toList();
    peers.sort((a, b) {
      final A = _dm[a];
      final B = _dm[b];
      final ta = (A != null && A.isNotEmpty) ? A.last.ts : DateTime.fromMillisecondsSinceEpoch(0);
      final tb = (B != null && B.isNotEmpty) ? B.last.ts : DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return peers;
  }

  void startDmPolling(String peer, {Duration every = const Duration(seconds: 2)}) {
    _dmTimers[peer]?.cancel();
    _pollDm(peer); // immediate
    _dmTimers[peer] = Timer.periodic(every, (_) => _pollDm(peer));
  }

  void stopDmPolling(String peer) {
    _dmTimers[peer]?.cancel();
    _dmTimers.remove(peer);
  }

  Future<void> _pollDm(String peer) async {
    final me = UserSession.username;
    if (me.isEmpty) return;

    final rows = await ChatApi.fetchDm(a: me, b: peer, afterIso: _lastDmIso[peer], limit: 200);
    if (rows.isEmpty) return;

    bool changed = false;
    final list = dmThread(peer);
    final seen = _dmSeenSet(peer);

    for (final dto in rows) {
      final serverId = '${dto.ts}-${dto.sender}';
      if (seen.contains(serverId)) {
        _lastDmIso[peer] = dto.ts;
        continue;
      }

      // match pending optimistic by same sender+text
      final idx = list.indexWhere((m) => m.pending && m.senderUser == dto.sender && m.text == dto.text);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(
          id: serverId,
          ts: DateTime.tryParse(dto.ts)?.toLocal() ?? list[idx].ts,
          pending: false,
        );
      } else {
        list.add(ChatMessage(
          id: serverId,
          senderUser: dto.sender,
          text: dto.text,
          ts: DateTime.tryParse(dto.ts)?.toLocal() ?? DateTime.now(),
          mine: dto.sender == me,
          pending: false,
        ));
      }

      seen.add(serverId);
      _lastDmIso[peer] = dto.ts;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  Future<void> postDm(String peer, String text) async {
    final me = UserSession.username;
    if (me.isEmpty || text.trim().isEmpty) return;

    final list = dmThread(peer);

    // optimistic append
    final now = DateTime.now();
    final tempId = 'pending-${now.microsecondsSinceEpoch}';
    list.add(ChatMessage(
      id: tempId,
      senderUser: me,
      text: text,
      ts: now,
      mine: true,
      pending: true,
    ));
    notifyListeners();

    try {
      await ChatApi.postDm(a: me, b: peer, sender: me, text: text);
      ActivityService.I.onDMSent(); // instant counters & lastActive
    } catch (_) {
      // ignore; optimistic stays
    }
  }
}
