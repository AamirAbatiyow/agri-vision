// lib/services/chat_api.dart
//
// Shim so existing pages that reference `ChatAPI` keep working.
// This forwards to ChatApi (defined in chat_store.dart).

// Re-export DTOs so other files can import them from here if they want.
export 'chat_store.dart' show GeneralDto, DmDto;

// Import the real implementation and the DTOs for use in signatures.
import 'chat_store.dart' show ChatApi, GeneralDto, DmDto;

class ChatAPI {
  static const String baseUrl = ChatApi.baseUrl;

  // -------- General --------
  static Future<List<GeneralDto>> fetchGeneral({
    String? afterIso,
    int limit = 200,
  }) =>
      ChatApi.fetchGeneral(afterIso: afterIso, limit: limit);

  static Future<void> postGeneral({
    required String sender,
    required String text,
  }) =>
      ChatApi.postGeneral(sender: sender, text: text);

  // -------- DMs --------
  static Future<List<DmDto>> fetchDm({
    required String a,
    required String b,
    String? afterIso,
    int limit = 200,
  }) =>
      ChatApi.fetchDm(a: a, b: b, afterIso: afterIso, limit: limit);

  static Future<void> postDm({
    required String a,
    required String b,
    required String sender,
    required String text,
  }) =>
      ChatApi.postDm(a: a, b: b, sender: sender, text: text);

  // -------- Threads --------
  static Future<List<Map<String, dynamic>>> fetchThreads(String username) =>
      ChatApi.fetchThreads(username);
}
