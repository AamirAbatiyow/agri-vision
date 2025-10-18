// lib/services/activity_service.dart
class ActivityService {
  ActivityService._();
  static final ActivityService I = ActivityService._();

  int dashboardViews = 0; // times the dashboard page was shown
  int sensorTicks = 0; // sensor snapshots processed
  int photoAnalyses = 0; // times "Analyze" ran in camera viewer
  int generalMessages = 0; // general chat messages sent
  int dmMessages = 0; // DM messages sent
  DateTime? lastActive; // last activity timestamp
  bool visitedAllTabs = false;

  // tab visit flags (to award "Pioneer")
  bool _home = false, _camera = false, _chat = false, _profile = false;

  void onDashboardViewed() {
    dashboardViews++;
    _home = true;
    _recheckPioneer();
  }

  void onSensorTick() => sensorTicks++;

  void onPhotoAnalyzed() {
    photoAnalyses++;
    _camera = true;
    _recheckPioneer();
  }

  void onChatVisited() {
    _chat = true;
    _recheckPioneer();
  }

  void onProfileVisited() {
    _profile = true;
    _recheckPioneer();
  }

  void onMessageSent({bool isDm = false}) {
    if (isDm) {
      dmMessages++;
    } else {
      generalMessages++;
    }
    lastActive = DateTime.now();
  }

  void _recheckPioneer() {
    visitedAllTabs = _home && _camera && _chat && _profile;
  }
}
