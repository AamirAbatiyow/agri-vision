class ActivityService {
  ActivityService._();
  static final ActivityService I = ActivityService._();

  int dashboardViews = 0;
  int sensorTicks = 0;
  int photoAnalyses = 0;
  bool visitedAllTabs = false;

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

  void _recheckPioneer() {
    visitedAllTabs = _home && _camera && _chat && _profile;
  }
}
