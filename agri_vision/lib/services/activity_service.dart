// lib/services/activity_service.dart

/// Global singleton to track user activity across the app:
/// - message counts (general / DM)
/// - crop analyses performed
/// - last active timestamp
/// - simple "visited screen" flags used by UI (e.g., chat hub, dashboard)
class ActivityService {
  // --- Singleton instance ---
  static final ActivityService I = ActivityService._internal();
  ActivityService._internal();

  // --- Counters / state ---
  int generalMessages = 0;
  int dmMessages = 0;
  int photoAnalyses = 0;
  DateTime? lastActive;

  // --- Visited flags (for UI cues/achievements) ---
  bool visitedDashboard = false;
  bool visitedChat = false;
  bool visitedProfile = false;
  bool visitedCamera = false;

  // --- Screen visit hooks (safe to call from pages) ---
  void onDashboardVisited() {
    visitedDashboard = true;
  }

  /// Alias to match pages that call onDashboardViewed()
  void onDashboardViewed() {
    onDashboardVisited();
  }

  void onChatVisited() {
    visitedChat = true;
  }

  void onProfileVisited() {
    visitedProfile = true;
  }

  void onCameraVisited() {
    visitedCamera = true;
  }

  // --- Instant-update triggers (called after successful actions) ---
  void onGeneralSent() {
    generalMessages += 1;
    lastActive = DateTime.now();
  }

  void onDMSent() {
    dmMessages += 1;
    lastActive = DateTime.now();
  }

  void onPhotoAnalyzed() {
    photoAnalyses += 1;
    lastActive = DateTime.now();
  }

  /// Called when a new sensor snapshot arrives on the dashboard streams.
  /// We simply bump lastActive so the profile’s "Last Active" reflects live data.
  void onSensorTick() {
    lastActive = DateTime.now();
  }

  // --- Optional utilities ---
  void reset() {
    generalMessages = 0;
    dmMessages = 0;
    photoAnalyses = 0;
    lastActive = null;
    visitedDashboard = false;
    visitedChat = false;
    visitedProfile = false;
    visitedCamera = false;
  }

  Map<String, dynamic> toJson() => {
        'generalMessages': generalMessages,
        'dmMessages': dmMessages,
        'photoAnalyses': photoAnalyses,
        'lastActive': lastActive?.toIso8601String(),
        'visitedDashboard': visitedDashboard,
        'visitedChat': visitedChat,
        'visitedProfile': visitedProfile,
        'visitedCamera': visitedCamera,
      };

  void loadFromJson(Map<String, dynamic> data) {
    generalMessages = data['generalMessages'] ?? 0;
    dmMessages = data['dmMessages'] ?? 0;
    photoAnalyses = data['photoAnalyses'] ?? 0;
    final last = data['lastActive'];
    if (last is String) lastActive = DateTime.tryParse(last);
    visitedDashboard = data['visitedDashboard'] ?? false;
    visitedChat = data['visitedChat'] ?? false;
    visitedProfile = data['visitedProfile'] ?? false;
    visitedCamera = data['visitedCamera'] ?? false;
  }
}
