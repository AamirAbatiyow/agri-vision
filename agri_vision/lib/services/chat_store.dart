// lib/services/chat_store.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'chat_api.dart';

class UserSession {
  static String username = 'guest';
  static String displayName = 'guest';

  static void set({required String user, required String name}) {
    username = user;
    displayName = name;
  }
}

class ChatMessage {
  final String id;            // server key (ts-sender) or local temp id
  final String senderUser;
  final String senderName;
  final String text;
  final DateTime ts;          // local or server
  final bool mine;
  final bool pending;         // <-- pending == true for optimistic local messages

  ChatMessage({
    required this.id,
    required this.senderUser,
    required this.senderName,
    required this.text,
    required this.ts,
    required this.mine,
    this.pending = false,
  });

  ChatMessage copyWith({
    String? id,
    String? senderUser,
    String? senderName,
    String? text,
    DateTime? ts,
    bool? mine,
    bool? pending,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderUser: senderUser ?? this.senderUser,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      ts: ts ?? this.ts,
      mine: mine ?? this.mine,
      pending: pending ?? this.pending,
    );
    }
}

// ---------- Store with Mongo polling + de-dupe ----------

class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore I = ChatStore._();

  // General
  final List<ChatMessage> general = [];
  final Set<String> _seenGeneralIds = {}; // server ids (ts-sender)

  // DM threads keyed by peer username
  final Map<String, List<ChatMessage>> _dm = {};
  final Map<String, Set<String>> _seenDmIds = {}; // by peer

  Timer? _pollTimerGeneral;
  final Map<String, Timer> _pollTimersDm = {};
  String? _lastGeneralIso; // last server ts we processed
  final Map<String, String?> _lastDmIso = {};

  // --- General Chat ---

  void startGeneralPolling({Duration every = const Duration(seconds: 2)}) {
    _pollTimerGeneral?.cancel();
    _pollGeneral(); // immediate
    _pollTimerGeneral = Timer.periodic(every, (_) => _pollGeneral());
  }

  void stopGeneralPolling() {
    _pollTimerGeneral?.cancel();
    _pollTimerGeneral = null;
  }

  Future<void> _pollGeneral() async {
    final rows = await ChatApi.fetchGeneral(afterIso: _lastGeneralIso, limit: 200);
    if (rows.isEmpty) return;

    bool changed = false;

    for (final dto in rows) {
      final serverId = '${dto.ts}-${dto.sender}';
      if (_seenGeneralIds.contains(serverId)) {
        // already integrated
        _lastGeneralIso = dto.ts;
        continue;
      }

      // try to match an existing pending optimistic message from same sender with same text
      final idx = general.indexWhere((m) =>
          m.pending &&
          m.senderUser == dto.sender &&
          m.text == dto.text);

      if (idx >= 0) {
        // convert pending to server-backed message
        final updated = general[idx].copyWith(
          id: serverId,
          ts: DateTime.tryParse(dto.ts)?.toLocal() ?? general[idx].ts,
          pending: false,
        );
        general[idx] = updated;
      } else {
        // add as new message
        general.add(ChatMessage(
          id: serverId,
          senderUser: dto.sender,
          senderName: dto.sender,
          text: dto.text,
          ts: DateTime.tryParse(dto.ts)?.toLocal() ?? DateTime.now(),
          mine: dto.sender == UserSession.username,
          pending: false,
        ));
      }

      _seenGeneralIds.add(serverId);
      _lastGeneralIso = dto.ts;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  Future<void> postGeneral(String text) async {
    final sender = UserSession.username;
    final now = DateTime.now();
    final tempId = 'pending-${now.microsecondsSinceEpoch}';

    // optimistic local append (pending=true)
    general.add(ChatMessage(
      id: tempId,
      senderUser: sender,
      senderName: sender,
      text: text,
      ts: now,
      mine: true,
      pending: true,
    ));
    notifyListeners();

    // send to server (server assigns ts; we reconcile on next poll)
    await ChatApi.postGeneral(sender: sender, text: text);
    // No need to do anything here; poll will match & convert pending → server
  }

  // --- DMs ---

  List<ChatMessage> dmThread(String peer) =>
      _dm.putIfAbsent(peer, () => <ChatMessage>[]);

  Set<String> _dmSeenSet(String peer) =>
      _seenDmIds.putIfAbsent(peer, () => <String>{});

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
    _pollTimersDm[peer]?.cancel();
    _pollDm(peer); // immediate
    _pollTimersDm[peer] = Timer.periodic(every, (_) => _pollDm(peer));
  }

  void stopDmPolling(String peer) {
    _pollTimersDm[peer]?.cancel();
    _pollTimersDm.remove(peer);
  }

  Future<void> _pollDm(String peer) async {
    final me = UserSession.username;
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

      // match a pending local message by same sender+text
      final idx = list.indexWhere((m) =>
          m.pending &&
          m.senderUser == dto.sender &&
          m.text == dto.text);

      if (idx >= 0) {
        final updated = list[idx].copyWith(
          id: serverId,
          ts: DateTime.tryParse(dto.ts)?.toLocal() ?? list[idx].ts,
          pending: false,
        );
        list[idx] = updated;
      } else {
        list.add(ChatMessage(
          id: serverId,
          senderUser: dto.sender,
          senderName: dto.sender,
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
    final now = DateTime.now();
    final tempId = 'pending-${now.microsecondsSinceEpoch}';

    final list = dmThread(peer);

    // optimistic local append (pending=true)
    list.add(ChatMessage(
      id: tempId,
      senderUser: me,
      senderName: me,
      text: text,
      ts: now,
      mine: true,
      pending: true,
    ));
    notifyListeners();

    // send to server; poll will reconcile
    await ChatApi.postDm(a: me, b: peer, sender: me, text: text);
  }
}
