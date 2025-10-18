// lib/services/chat_store.dart
import 'dart:collection';

/// Simple user session (set this from login/signup).
class UserSession {
  static String username = 'guest';
  static String displayName = 'Guest';
  static void set({required String user, required String name}) {
    username = user.trim().isEmpty ? 'guest' : user.trim();
    displayName = name.trim().isEmpty ? username : name.trim();
  }
}

/// Chat message model.
class ChatMessage {
  final String id;          // unique per message (simple counter-based)
  final String senderUser;  // username
  final String senderName;  // display name at send time
  final String text;
  final DateTime ts;
  final bool isDM;
  final String? peerUser;   // DM peer username (null for general chat)

  ChatMessage({
    required this.id,
    required this.senderUser,
    required this.senderName,
    required this.text,
    required this.ts,
    this.isDM = false,
    this.peerUser,
  });
}

/// In-memory chat store (general + DMs).
class ChatStore {
  ChatStore._();
  static final ChatStore I = ChatStore._();

  // Auto-increment id.
  int _nextId = 1;
  String _genId() => (_nextId++).toString();

  // General chat messages (append-only queue).
  final List<ChatMessage> _general = [];

  // DM threads keyed by the OTHER participant username (sorted by most recent).
  final Map<String, List<ChatMessage>> _dmByPeer = {};

  // List of known users (for demo mention list / DM target). Seed a few.
  final Set<String> _knownUsers = {'guest', 'leafy', 'plantr', 'sprout', 'grower'};

  // ------------- General Chat -------------
  UnmodifiableListView<ChatMessage> get general =>
      UnmodifiableListView(_general);

  void postGeneral(String text) {
    if (text.trim().isEmpty) return;
    final msg = ChatMessage(
      id: _genId(),
      senderUser: UserSession.username,
      senderName: UserSession.displayName,
      text: text.trim(),
      ts: DateTime.now(),
      isDM: false,
    );
    _general.add(msg);
    _knownUsers.add(UserSession.username);
  }

  // ------------- Direct Messages -------------
  List<ChatMessage> dmThread(String peerUser) =>
      _dmByPeer.putIfAbsent(_normalizePeer(peerUser), () => <ChatMessage>[]);

  void postDM({required String peerUser, required String text}) {
    if (text.trim().isEmpty) return;
    final peer = _normalizePeer(peerUser);
    final bucket = _dmByPeer.putIfAbsent(peer, () => <ChatMessage>[]);
    final msg = ChatMessage(
      id: _genId(),
      senderUser: UserSession.username,
      senderName: UserSession.displayName,
      text: text.trim(),
      ts: DateTime.now(),
      isDM: true,
      peerUser: peer,
    );
    bucket.add(msg);
    _knownUsers.addAll({UserSession.username, peer});
  }

  // Returns peers sorted by latest message time desc.
  List<String> dmPeersByRecency() {
    final entries = _dmByPeer.entries.toList();
    entries.sort((a, b) {
      final aTs = a.value.isEmpty ? DateTime.fromMillisecondsSinceEpoch(0) : a.value.last.ts;
      final bTs = b.value.isEmpty ? DateTime.fromMillisecondsSinceEpoch(0) : b.value.last.ts;
      return bTs.compareTo(aTs);
    });
    return entries.map((e) => e.key).toList();
  }

  // ------------- Users / Mentions -------------
  List<String> knownUsers({bool excludeMe = true}) {
    final me = UserSession.username;
    final list = _knownUsers.toList()..sort();
    return excludeMe ? list.where((u) => u != me).toList() : list;
  }

  // For demo convenience, reset store.
  void resetDemo() {
    _general.clear();
    _dmByPeer.clear();
    _knownUsers
      ..clear()
      ..addAll({'guest', 'leafy', 'plantr', 'sprout', 'grower'});
    _nextId = 1;
  }

  String _normalizePeer(String u) => u.trim().toLowerCase();
}
